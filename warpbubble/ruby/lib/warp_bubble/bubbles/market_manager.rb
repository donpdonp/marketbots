require 'heisencoin'

class WarpBubble
  class MarketManager < Base
    def initialize
      super
      @arby = Heisencoin::Arbitrage.new
      exchanges = get('exchange_list').map do |exchange|
        Heisencoin::Exchange.new(get('warpbubble:'+exchange))
      end
      log("setting up exchanges #{exchanges}")
      @arby.add_exchanges(exchanges)
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
        log("!Plan for #{@arby.exchanges.map(&:name)}. #{@arby.asks.offers.size} asks and #{@arby.bids.offers.size} bids")
        good_asks = @arby.profitable_asks
        if good_asks.size > 0
          plan = @arby.plan
          log("plan: #{plan}")
          total = plan.reduce(0){|sum,p|sum+p[4]}
          log("#{plan[0][0].name} #{"%0.3f"%total} coins -> #{plan[0][2].name}")
          publish({'action' => 'plan ready', 'payload' => {'plan' => plan}})
        else
          log("Spread is #{"%0.5f" % @arby.spread}. #{@arby.asks.offers.first.exchange.name} leads. no strategy available.")
        end
      end
    end

    def plan_ready(payload)
      log('plan ready '+payload.inspect)
      publish({'action' => 'exchange balance', 'payload' => {'exchange'=>'btce'}})
    end

    def balance_ready(payload)
      log("balance ready #{payload}")
    end

  end
end

WarpBubble.add_service({"name" => "MarketManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
