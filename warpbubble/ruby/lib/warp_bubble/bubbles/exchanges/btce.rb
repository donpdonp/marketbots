class WarpBubble
  class Exchanges
    class Btce < Base

      def go
        @chan_sub.subscribe(@@channel_name) do |on|
          on.message do |channel, json|
            message = JSON.parse(json)
            if message['payload'] && message['payload']['exchange'] == 'btce'
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
        publish({"action" => "balance ready", "payload" => {"exchange" => "btce",
                                                            "amount" => 1,
                                                            "currency" => "ltc"}})
      end

    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Btce", "thread" => Thread.new do
  WarpBubble::Exchanges::Btce.new.go
end})

