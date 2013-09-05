class WarpBubble
  class MarketManager < Base
    def go
      @chan_sub.subscribe(@@channel_name) do |on|
        on.subscribe do |channel, count|
        end

        on.message do |channel, json|
          message = JSON.parse(json)
          puts "MarketManager: "+message.inspect
        end
      end
    end
  end
end

WarpBubble.add_service({"name" => "MaretManager", "thread" => Thread.new do
  WarpBubble::MarketManager.new.go
end})
