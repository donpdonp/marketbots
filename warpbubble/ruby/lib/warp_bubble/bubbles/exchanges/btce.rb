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
        order_detail = {'pair' => 'ltc_btc',
                        'type' => payload['order'],
                        'rate' => payload['price'],
                        'quantity' => payload['quantity']}
        log "ORDER GO #{order_detail}"
        post('createorder', order_detail)
        super
      end

      def post(command, params = {})
        params["method"] = command
        params["nonce"] = Time.now.to_i.to_s
        headers = {'Key' => @api_key, 'Sign' => sign(params)}
        result = HTTParty.post @@api_url, {:body => params, :headers => headers, :format => :json}
        if result.parsed_response["success"] == 1
          result.parsed_response["return"]
        else
          log "API error "+result.response
        end
      end

    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Btce", "thread" => Thread.new do
  WarpBubble::Exchanges::Btce.new.go
end})

