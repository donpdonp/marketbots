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
      @state = "waiting"
    end

    def go
      @chan_sub.subscribe(@@channel_name) do |on|
        on.subscribe do |channel, count|
        end

        on.message do |channel, json|
          message = JSON.parse(json)
          case message["action"]
          when "exchange ready"
            exchange_ready(message["payload"])
          when "plan ready"
            plan_ready(message["payload"])
          when "balance ready"
            balance_ready(message["payload"])
          end
        end
      end
    end

    def exchange_ready(message)
      exchange = @arby.exchange(message['name'])
      puts "!! exchange #{message['name']} not found " unless exchange
      now = Time.now
      exchange.time = now
      @arby.add_depth(exchange, message['depth'])
      times = @arby.exchanges.map{|r| r.time ? (now - r.time) : nil }
      recent = times.all? {|t| t && t < 30}
      if recent
        log("Generating plan for #{@arby.exchanges.map(&:name)}. #{@arby.asks.offers.size} asks and #{@arby.bids.offers.size} bids")
        good_asks = @arby.profitable_asks
        if good_asks.size > 0
          plan = @arby.plan
          log("generated plan: #{plan.steps.size} steps. "+
              "#{"%0.4f"%plan.profit} profit. "+
              "#{plan.steps.first.from_offer.exchange.name} #{"%0.3f"%plan.quantity} coins -> "+
              "#{plan.steps.first.to_offer.exchange.name}")
          publish({'action' => 'plan ready', 'payload' => {'plan' => plan.to_simple}})
        else
          log("Spread is #{"%0.5f" % @arby.spread}. #{@arby.asks.offers.first.exchange.name} leads. no strategy available.")
        end
      end
    end

    def plan_ready(payload)
      plan = Heisencoin::Plan.new(payload['plan'])
        if @state == "waiting"
          @state = "buy"
          exg_name = plan.steps.first.from_offer.exchange.name
          balances = balance_load(exg_name)
          purse = balances["object"]["btc"]
          log "pre-plan: #{exg_name} #{purse}btc available"
        elsif @state == "buy"
          @state = "sell"
          exg_name = plan.steps.first.to_offer.exchange.name
          balances = balance_load(exg_name)
          purse = balances["object"]["ltc"]
          log "pre-plan: #{exg_name} #{purse}ltc available"
        else
          log "order in process. skipping this plan."
          return
        end
        place_orders(@state, plan, purse)
    end

    def balance_load(exchange_name)
      json = @chan_pub.get("warpbubble:balance:#{exchange_name}")
      if json
        JSON.parse(json)
      else
        log "ERROR missing balance"
      end
    end

    def place_orders(state, plan, purse)
      plan.steps.each do |step|
        if purse <= 0
          log('out of money')
          break
        end
        offer = step.from_offer if state == 'buy'
        offer = step.to_offer if state == 'sell'
        coins_afforded = purse/offer.price
        coins_spent = [coins_afforded, step.quantity].min
        cost = coins_spent*offer.price
        log "#{purse} remains. #{state} offer: #{offer.exchange.name} #{offer.price} x#{step.quantity} with x#{coins_spent} #{"%0.5f"%cost}btc"
        publish({:action => 'order', :payload => {:exchange => offer.exchange.name,
                                                  :order => state,
                                                  :price => offer.price,
                                                  :quantity => coins_spent} })
        purse -= cost
      end
    end

  end
end

WarpBubble.add_service({"name" => "MarketManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
