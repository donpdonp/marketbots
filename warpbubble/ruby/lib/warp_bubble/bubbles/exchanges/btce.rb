class WarpBubble
  class Exchanges
    class Btce < Base

      @@api_url = "https://btc-e.com/tapi"

      def initialize
        super
        @api_key = @chan_pub.get('btce:key')
        @api_secret = @chan_pub.get('btce:secret')
        unless @api_key && @api_secret
          log("Warning: no API Key")
        end
      end

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
        balances = post('getInfo')
        publish({"action" => "balance ready", "payload" => {"exchange" => "btce",
                                                            "amount" => balances["funds"][payload["currency"]],
                                                            "currency" => payload["currency"]}})
      end

      def post(command, params = {})
        params["method"] = command
        params["nonce"] = Time.now.to_i.to_s
        headers = {'Key' => @api_key, 'Sign' => sign(params)}
        result = HTTParty.post @@api_url, {:body => params, :headers => headers, :format => :json}
        if result.parsed_response["success"] == 1
          result.parsed_response["return"]
        end
      end

      def sign(params)
        hmac = OpenSSL::HMAC.new(@api_secret, OpenSSL::Digest::SHA512.new)
        hmac.update(URI.encode_www_form(params)).to_s
      end
    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Btce", "thread" => Thread.new do
  WarpBubble::Exchanges::Btce.new.go
end})

