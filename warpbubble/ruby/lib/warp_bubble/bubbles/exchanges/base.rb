class WarpBubble
  class Exchanges
    class Base < WarpBubble::Base

      def initialize(short_name)
        super()
        @short_name = short_name
        @api_key = @chan_pub.get("#{short_name}:key")
        @api_secret = @chan_pub.get("#{short_name}:secret")
        unless @api_key && @api_secret
          log("Warning: no API Key")
        end
        balance_refresh
      end

      def go
        @chan_sub.subscribe(@@channel_name) do |on|
          on.message do |channel, json|
            message = JSON.parse(json)
            if message['payload'] && message['payload']['exchange'] == @short_name
              case message["action"]
              when "exchange balance"
                balance(message["payload"])
              when "order"
                order(message["payload"])
              end
            end
          end
        end
      end

      def balance(payload)
        publish({"action" => "balance ready", "payload" => {"exchange" => @short_name,
                                                            "balances" => @balances}})
      end

      def order(payload)
        log "order #{payload}"
        publish({"action" => "order complete", "payload" => {"exchange" => "btce",
                                                             "balances" => @balances}})
      end

    end
  end
end