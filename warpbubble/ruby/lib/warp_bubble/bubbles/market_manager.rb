require 'heisencoin/arbitrage'

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
        get('warpbubble:'+exchange)
      end
      now = Time.now
      times = runs.map{|r| now - Time.parse(r["time"])}
      log(times.inspect)
      recent = times.all? {|t| t < 5}
      if recent
        log('depth recent. go!')
        arby = Heisencoin::Arbitrage.new
        arby.add_exchanges(runs)
        arby.plan
      end
    end
  end
end

WarpBubble.add_service({"name" => "MarketManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
