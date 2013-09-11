require 'heisencoin'

class WarpBubble
  class MarketManager < Base
    def go
      @chan_sub.subscribe(@@channel_name) do |on|
        on.subscribe do |channel, count|
        end

        on.message do |channel, json|
          message = JSON.parse(json)
          case message["action"]
          when "exchange ready"
            exchange_ready(message)
          end
        end
      end
    end

    def exchange_ready(message)
      #check for all the exchanges being ready
      runs = get('exchange_list').map do |exchange|
        Heisencoin::Exchange.new(get('warpbubble:'+exchange))
      end
      now = Time.now
      times = runs.map{|r| now - r.time}
      log("exchange timing #{times.inspect}")
      recent = times.all? {|t| t < 3000}
      if recent
        arby = Heisencoin::Arbitrage.new
        arby.add_exchanges(runs)
        puts "!Plan for #{arby.exchanges.size} exchanges of #{arby.asks.offers.size} asks and #{arby.bids.offers.size} bids"
        puts "best ask #{arby.asks.offers.first} best bid #{arby.bids.offers.first}"
        puts "#{arby.profitable_asks.size} asks are under a bid"
        puts arby.plan.inspect
      end
    end
  end
end

WarpBubble.add_service({"name" => "MarketManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
