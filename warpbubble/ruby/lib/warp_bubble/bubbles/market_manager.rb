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
      @in_plan = false
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
      from_name = plan.steps.first.from_offer.exchange.name
      to_name = plan.steps.first.to_offer.exchange.name
      from_balance = @chan_pub.get("warpbubble:balance:#{from_name}")
      if from_balance
        balances = JSON.parse(from_balance)
        log "pre-plan: #{from_name} #{balances["object"]["btc"]} available"
        if @in_order
          log "order in process. skipping this plan."
        else
          @in_order = true
          place_orders(plan, balances["object"]["btc"])
        end
      else
        log("missing balance for #{from_name}")
      end
    end

    def place_orders(plan, purse)
      plan.steps.each do |step|
        if purse <= 0
          log('out of money')
          break
        end
        coins_afforded = purse/step.from_offer.price
        coins_spent = [coins_afforded, step.quantity].min
        cost = coins_spent*step.from_offer.price
        log "#{purse} remains. Buy offer: #{step.from_offer.exchange.name} #{step.from_offer.price} x#{step.quantity} with x#{coins_spent} #{"%0.5f"%cost}btc"
        publish({:action => 'order', :payload => {:exchange => step.from_offer.exchange.name,
                                                  :order => 'buy',
                                                  :price => step.from_offer.price,
                                                  :quantity => coins_spent} })
        purse -= cost
      end
    end

  end
end

WarpBubble.add_service({"name" => "MarketManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
