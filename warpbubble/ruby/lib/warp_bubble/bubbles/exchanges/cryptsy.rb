require 'time'

class WarpBubble
  class Exchanges
    class Cryptsy < Base

      @@short_name = 'cryptsy'
      @@api_url = "https://www.cryptsy.com/api"

      def initialize
        super(@@short_name)
        balance_refresh
      end

      def balance_refresh
        balances = post('getinfo')
        @balances = {}
        balances["balances_available"].each{|key, value| @balances[key.downcase] = value.to_f }
        log("balance refresh. #{@balances['ltc']} ltc #{@balances['btc']} btc. #{balances["openordercount"]} open orders")
        blnce = { type: 'Exchange#balance',
                  time: Time.at(balances["servertimestamp"]).iso8601,
                  object: @balances }
        @chan_pub.set("warpbubble:balance:#{@@short_name}", blnce.to_json)
      end


      def post(command, params = {})
        params["method"] = command
        params["nonce"] = Time.now.to_i.to_s
        headers = {'Key' => @api_key, 'Sign' => sign(params)}
        result = HTTParty.post @@api_url, {:body => params, :headers => headers, :format => :json}
        if result.parsed_response["success"] == "1"
          result.parsed_response["return"]
        else
          log "API error "+result.response
        end
      end

    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Cryptsy", "thread" => Thread.new do
  WarpBubble::Exchanges::Cryptsy.new.go
end})

