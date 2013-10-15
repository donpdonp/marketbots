require 'heisencoin'

class WarpBubble
  class MarketManager < Base
    def initialize
      super
      @arby = Heisencoin::Arbitrage.new
      exchanges = get('exchange_list').map do |exchange|
        Heisencoin::Exchange.new(get('warpbubble:'+exchange))
      end
      log("setting up exchanges #{exchanges.map(&:name)}")
      @arby.add_exchanges(exchanges)
    end

    def go
      @chan_sub.subscribe(@@channel_name) do |on|
        on.subscribe do |channel, count|
        end

        on.message do |channel, json|
          message = JSON.parse(json)
          case message["action"]
          when "time"
            plan_time(message["payload"])
          when "depth ready"
            depth_ready(message["payload"])
          when "plan ready"
            plan_ready(message["payload"])
          when "plan drop"
            plan_drop(message["payload"])
          when "balance ready"
            balance_ready(message["payload"])
          end
        end
      end
    end

    def depth_ready(message)
      exchange = @arby.exchange(message['name'])
      puts "!! exchange #{message['name']} not found " unless exchange
      now = Time.now
      exchange.time = now
      @arby.add_depth(exchange, message['depth'])
      log "Depth added for #{exchange.name}"
      times = @arby.exchanges.map{|r| r.time ? (now - r.time) : nil }
      recent = times.all? {|t| t && t < 30}
      if recent
        log("Generating plan for #{@arby.exchanges.map{|e| "#{e.name} #{e.fee*100}%"}.join(' ')}. "+
            "#{@arby.asks.offers.size} asks and #{@arby.bids.offers.size} bids")
        plan = @arby.plan
        if plan.steps.size > 0
          log("Plan: #{plan.steps.size} steps. "+
              "#{"%0.4f"%plan.profit} profit. "+
              "#{plan.steps.first.from_offer.exchange.name} #{"%0.3f"%plan.quantity} coins -> "+
              "#{plan.steps.first.to_offer.exchange.name}")
          if @chan_pub.exists('warpbubble:plan')
            plan = Heisencoin::Plan.new(get('warpbubble:plan'))
            log("Existing plan in #{plan.state}/#{plan.purse}. Skipping plan execution.")
          else
            if plan.profit >= 0.01
              set('warpbubble:plan', plan.to_simple)
              publish({'action' => 'plan ready', 'payload' => {}})
            else
              log 'insuficient profit. skipping plan.'
            end
          end
        else
          msg = "Spread is #{"%0.5f" % @arby.spread}. #{@arby.asks.offers.first.exchange.name} leads. no strategy available."
          if @chan_pub.exists('warpbubble:plan')
            plan = Heisencoin::Plan.new(get('warpbubble:plan'))
            msg = "Existing plan in #{plan.state}/#{plan.purse}. "+msg
          end
          log(msg)
        end
      end
    end

    def plan_drop(payload)
      @chan_pub.del('warpbubble:plan')
      log 'plan dropped'
    end

    def plan_ready(payload)
      plan = Heisencoin::Plan.new(get('warpbubble:plan'))
        if plan.state == "planning"
          plan.state = "buying"
          exg = plan.steps.first.from_offer.exchange
          balances = balance_load(exg.name)
          if balances
            purse = balances["object"]["btc"]
            if purse > 0.001
              purse_trim = purse - 0.00000001
              log "Go plan: plan cost #{"%0.8f"%plan.cost}. #{exg.name} #{"%0.8f"%purse}btc (trimmed #{"%0.8f"%purse_trim})available."
              nma("Buying #{exg.name} plan cost #{"%0.5f"%plan.cost}btc. #{"%0.5f"%purse}btc available.")
              place_orders(plan, purse_trim, exg.fee)
              plan.state = "bought"
              set('warpbubble:plan', plan.to_simple)
            else
              log "#{exg.name} is out of coins"
            end
          else
            log "missing balances report for #{exg.name}"
          end
        else
          log "plan in #{plan.state}. skipping this plan."
          return
        end
    end

    def plan_time(payload)
      @last_time ||= Time.now
      if Time.now - @last_time > 30
        @last_time = Time.now
        return unless @chan_pub.exists('warpbubble:plan')
        plan = Heisencoin::Plan.new(get('warpbubble:plan'))
        if plan.state == "bought"
          log "Time: plan.state/bought. balance refresh"
          from_exg = plan.steps.first.from_offer.exchange
          if balance_load(from_exg.name)
            publish({"action" => "balance refresh", "payload" => {"exchange" => from_exg.name}})
          end
        end
        if plan.state == "email"
          log "Time: plan.state/email. email check"
          from_exg = plan.steps.first.from_offer.exchange
          publish({"action" => "check email", "payload" => {"exchange" => from_exg.name}})
        end
      end
    end

    def balance_ready(payload)
      return unless @chan_pub.exists('warpbubble:plan')
      plan = Heisencoin::Plan.new(get('warpbubble:plan'))
      if plan.state == "bought"
        plan.state = "moving"
        from_exg = plan.steps.first.from_offer.exchange
        balances = balance_load(from_exg.name)
        return unless balances
        if balances["object"]["ltc"] >= plan.purse
          to_exg = plan.steps.first.to_offer.exchange
          log "move: #{plan.purse}ltc #{from_exg.name} => #{to_exg.name}"
          address = @chan_pub.get("#{to_exg.name}:deposit:ltc")
          publish({'action' => 'transfer', 'payload' => {"exchange" => from_exg.name,
                                                         "amount" => plan.purse,
                                                         "currency" => 'ltc',
                                                         "address" => address}})
          plan.state = "email"
          set('warpbubble:plan', plan.to_simple)
        else
          log "#{from_exg.name} balance of #{balances["object"]["ltc"]} is not purse #{plan.purse}"
        end
      elsif plan.state == "moved"
        plan.state = "selling"
        exg = plan.steps.first.to_offer.exchange
        balances = balance_load(exg.name)
        balance = balances["object"]["ltc"]
        log "post-plan: #{exg.name} #{"%0.8f"%balance}ltc available. plan purse #{"%0.8f"%plan.purse}"
        if balance > plan.purse
          place_orders(plan, plan.purse, exg.fee)
          fee = plan.steps.first.from_offer.exchange.fee+plan.steps.first.to_offer.exchange.fee
          log "post-plan profit #{plan.purse-plan.spent}btc - #{fee}%fee = #{(plan.purse-plan.spent)*(1-fee)}btc"
          plan.state = "sold"
          set('warpbubble:plan', plan.to_simple)
        else
          log "post-plan: balance of #{balance} is not sufficient for plan purse of #{plan.purse}. waiting for deposit."
        end
      else
        log "plan in #{plan.state}. skipping this balance."
      end
    end

    def balance_load(exchange_name)
      json = @chan_pub.get("warpbubble:balance:#{exchange_name}")
      if json
        JSON.parse(json)
      else
        log "ERROR missing balance for #{exchange_name}"
      end
    end

    def place_orders(plan, purse, fee)
      if plan.state == 'buying'
        state = 'buy'
      elsif plan.state == 'selling'
        state = 'sell'
      else
        log "wrong state to place orders: #{plan.state}"
        return
      end
      expense = 0.0
      acquired = 0.0
      plan.steps.each do |step|
        remaining = purse - expense if state == 'buy'
        remaining = purse - acquired if state == 'sell'
        if remaining <= 0.0001
          log("out of money.")
          break
        end
        offer = step.from_offer if state == 'buy'
        offer = step.to_offer if state == 'sell'
        coins_afforded = remaining/offer.price*(1-fee) if state == 'buy'
        coins_afforded = remaining if state == 'sell'
        coins_spent = [coins_afforded, step.quantity].min
        cost = coins_spent*offer.price
        log "#{"%0.8f"%remaining} remains. #{state} offer: #{offer.exchange.name} #{offer.price} x#{step.quantity}. consuming x#{coins_spent} = #{"%0.5f"%cost}btc"
        publish({:action => 'order', :payload => {:exchange => offer.exchange.name,
                                                  :order => state,
                                                  :price => offer.price,
                                                  :quantity => coins_spent} })
        expense += cost
        acquired += coins_spent
      end
      if state == 'buy'
        plan.purse = acquired
        plan.spent = expense
      end
      if state == 'sell'
        plan.purse = expense*(1-fee)
      end
      log("#{state} orders finished. totals #{expense}btc #{acquired}ltc. plan.purse = #{plan.purse}. plan.spent = #{plan.spent}")
    end

  end
end

WarpBubble.add_service({"name" => "MarketManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
