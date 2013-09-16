class WarpBubble
  class Exchanges
    class Btce < Base

      def go
        @chan_sub.subscribe(@@channel_name) do |on|
          on.message do |channel, json|
            message = JSON.parse(json)
            if message['exchange'] == 'btce'
              case message["action"]
              when "exchange balance"
                balance(message["payload"])
              end
            end
          end
        end
      end

      def balance(payload)
        log("balance request")
      end

    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Btce", "thread" => Thread.new do
  WarpBubble::Exchanges::Btce.new.go
end})

