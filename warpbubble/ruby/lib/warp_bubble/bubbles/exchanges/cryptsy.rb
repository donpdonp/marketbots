class WarpBubble
  class Exchanges
    class Cryptsy < Base

      @@api_url = "https://www.cryptsy.com/api"

      def initialize
        super
        @api_key = @chan_pub.get('cryptsy:key')
        @api_secret = @chan_pub.get('cryptsy:secret')
        unless @api_key && @api_secret
          log("Warning: no API Key")
        end
      end

      def go
        @chan_sub.subscribe(@@channel_name) do |on|
          on.message do |channel, json|
            message = JSON.parse(json)
            if message['payload'] && message['payload']['exchange'] == 'cryptsy'
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
        balances = post('getinfo')
        publish({"action" => "balance ready", "payload" => {"exchange" => "cryptsy",
                                                            "amount" => balances["balances_available"][payload["currency"].upcase],
                                                            "currency" => payload["currency"]}})
      end

      def post(command, params = {})
        params["method"] = command
        params["nonce"] = Time.now.to_i.to_s
        headers = {'Key' => @api_key, 'Sign' => sign(params)}
        result = HTTParty.post @@api_url, {:body => params, :headers => headers, :format => :json}
        if result.parsed_response["success"] == "1"
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

WarpBubble.add_service({"name" => "Exchanges::Cryptsy", "thread" => Thread.new do
  WarpBubble::Exchanges::Cryptsy.new.go
end})

