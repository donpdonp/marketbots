class WarpBubble
  class Exchanges
    class Btce < Exchanges::Base

      @@short_name = 'btce'
      @@api_url = "https://btc-e.com/tapi"

      def initialize
        super(@@short_name)
        balance_refresh
      end

      def balance_refresh
        @balances = post('getInfo')
        log("balance refresh. #{@balances['funds']['ltc']} ltc #{@balances['funds']['btc']} btc. #{@balances["open_orders"]} open orders")
        blnce = { type: 'Exchange#balance',
                  time: Time.at(@balances["server_time"]).iso8601,
                  object: @balances["funds"] }
        @chan_pub.set('warpbubble:balance:btce', blnce.to_json)
      end

      def order(payload)
        # sensitive to number of decimals
        order_detail = {'pair' => 'ltc_btc',
                        'type' => payload['order'],
                        'rate' => trim_float(payload['price'],8),
                        'amount' => trim_float(payload['quantity'],8) }
        log "ORDER GO #{order_detail}"
        post('Trade', order_detail)
        super
      end

      def post(command, params = {})
        params["method"] = command
        # btc-e nonce capped at unixtime.
        nonce = @chan_pub.get("#{@@short_name}:nonce").to_i+1
        @chan_pub.set("#{@@short_name}:nonce", nonce)
        params["nonce"] = nonce
        headers = {'Key' => @api_key, 'Sign' => sign(params)}
        result = HTTParty.post @@api_url, {:body => params, :headers => headers, :format => :json}
        log "API "+result.response.body
        if result.parsed_response["success"] == 1
          result.parsed_response["return"]
        end
      end

    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Btce", "thread" => Thread.new do
  WarpBubble::Exchanges::Btce.new.go
end})

