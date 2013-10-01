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
          when "depth ready"
            depth_ready(message["payload"])
          when "plan ready"
            plan_ready(message["payload"])
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
      times = @arby.exchanges.map{|r| r.time ? (now - r.time) : nil }
      recent = times.all? {|t| t && t < 30}
      if recent
        if @chan_pub.exists('warpbubble:plan')
          log('existing plan. skipping plan generation')
        else
          log("Generating plan for #{@arby.exchanges.map{|e| "#{e.name} #{e.fee*100}%"}.join(' ')}. "+
              "#{@arby.asks.offers.size} asks and #{@arby.bids.offers.size} bids")
          plan = @arby.plan
          if plan.steps.size > 0
            log("generated plan: #{plan.steps.size} steps. "+
                "#{"%0.4f"%plan.profit} profit. "+
                "#{plan.steps.first.from_offer.exchange.name} #{"%0.3f"%plan.quantity} coins -> "+
                "#{plan.steps.first.to_offer.exchange.name}")
            if plan.profit >= 0.01
              set('warpbubble:plan', plan.to_simple)
              publish({'action' => 'plan ready', 'payload' => {}})
            else
              log 'insuficient profit. skipping plan.'
            end
          else
            log("Spread is #{"%0.5f" % @arby.spread}. #{@arby.asks.offers.first.exchange.name} leads. no strategy available.")
          end
        end
      end
    end

    def plan_ready(payload)
      plan = Heisencoin::Plan.new(get('warpbubble:plan'))
        if plan.state == "planning"
          plan.state = "buying"
          exg = plan.steps.first.from_offer.exchange
          balances = balance_load(exg.name)
          purse = balances["object"]["btc"]
          purse_after_fee = purse*(1-exg.fee)
          log "pre-plan: #{exg.name} #{"%0.8f"%purse}btc available. #{"%0.8f"%purse_after_fee} after fee. plan cost #{"%0.8f"%plan.cost}"
          place_orders(plan, purse_after_fee)
          plan.state = "bought"
          set('warpbubble:plan', plan.to_simple)
        else
          log "plan in #{plan.state}. skipping this plan."
          return
        end
    end

    def balance_ready(payload)
      plan = Heisencoin::Plan.new(get('warpbubble:plan'))
      if plan.state == "bought"
        plan.state = "selling"
        exg = plan.steps.first.to_offer.exchange
        balances = balance_load(exg.name)
        balance = balances["object"]["ltc"]
        balance_after_fee = balance*(1-exg.fee)
        log "post-plan: #{exg.name} #{"%0.8f"%balance}ltc available. #{"%0.8f"%balance_after_fee} after fee. plan purse #{"%0.8f"%plan.purse}"
        if balance > plan.purse
          place_orders(plan, plan.purse)
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
        log "ERROR missing balance"
      end
    end

    def place_orders(plan, purse)
      if plan.state == 'buying'
        state = 'buy'
      elsif plan.state == 'selling'
        state = 'sell'
      else
        log "wrong state to place orders: #{plan.state}"
        return
      end
      expense = 0.0
      acquired = 0
      plan.steps.each do |step|
        remaining = purse - expense if state == 'buy'
        remaining = purse - acquired if state == 'sell'
        if remaining <= 0.00001
          log("out of money.")
          break
        end
        offer = step.from_offer if state == 'buy'
        offer = step.to_offer if state == 'sell'
        coins_afforded = remaining/offer.price if state == 'buy'
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
        plan.purse = expense
      end
      log("#{state} orders finished. totals #{expense}btc #{acquired}ltc. plan.purse = #{plan.purse}. plan.spent = #{plan.spent}")
    end

  end
end

WarpBubble.add_service({"name" => "MarketManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
