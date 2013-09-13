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
      log("exchange timings #{times.inspect}")
      recent = times.all? {|t| t && t < 30}
      if recent
        puts "!Plan for #{@arby.exchanges.size} exchanges of #{@arby.asks.offers.size} asks and #{@arby.bids.offers.size} bids"
        good_asks = @arby.profitable_asks
        if good_asks.size > 0
          plan = @arby.plan
          puts "plan: #{plan}"
          total = plan.reduce(0){|sum,p|sum+p[4]}
          puts "#{plan[0][0].name} #{"%0.3f"%total} coins -> #{plan[0][2].name}"
        else
          puts "Spread is #{"%0.5f" % @arby.spread}. no strategy available."
        end
      end
    end
  end
end

WarpBubble.add_service({"name" => "MarketManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
