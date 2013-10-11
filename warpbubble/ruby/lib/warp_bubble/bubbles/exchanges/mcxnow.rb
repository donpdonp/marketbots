require 'rexml/document'

class WarpBubble
  class Exchanges
    class Mcxnow < Exchanges::Base

      @@short_name = 'mcxnow'
      @@api_url = "https://mcxnow.com/action"
      @@base_url = "https://mcxnow.com/"
      #@@base_url = "http://localhost:8002/"
      @@login_url = "https://mcxnow.com/login.html"

      def initialize
        super(@@short_name)
      end

      def balance_refresh(payload)
        @balances = {}
        html = post('account.html')
        xml_regex = /var startData='(<.*doc>)';/m
        xml = xml_regex.match(html)
        doc = REXML::Document.new xml[1]
        doc.elements.each('doc/cur') do |e|
          code = ""
          e.elements.each('tla'){|e| code = e.text.downcase}
          e.elements.each('balavail'){|e| @balances[code] = e.text.to_f}
        end
        msg = "balance refresh. #{"%0.8f"% @balances['ltc']} ltc. "+
              "#{"%0.8f"% @balances['btc']} btc. "+
              "#{@balances["open_orders"]} open orders"
        log(msg)
        blnce = { type: 'Exchange#balance',
                  time: Time.now.iso8601,
                  object: @balances }
        @chan_pub.set("warpbubble:balance:#{@@short_name}", blnce.to_json)
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

      def order_drop(payload)
        log "Order Drop!"
        orders = post('ActiveOrders')
        orders && orders.each do |id, detail|
          log "Cancelling order #{detail['pair']} x#{detail['amount']}"
          post('CancelOrder', {'order_id' => id})
        end
      end

      def post(path, params = {})
        login unless @key
        headers = {'Cookie' => "mcx_sess=#{@session}; mcx_key=#{@key}",
                   'User-Agent' => 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:24.0) Gecko/20100101 Firefox/24.0'}
        url = @@base_url+path
        result = HTTParty.post url, {:body => params, :headers => headers}
        if result.code == 200
          result.parsed_response
        else
        end
      end

      def login
        user = @chan_pub.get("#{@@short_name}:username")
        password = @chan_pub.get("#{@@short_name}:password")
        params = {"user"=>user, "pass" => password}
        result = HTTParty.post @@login_url, {:body => params}
        @cookie = result.headers['Set-Cookie']
        session_match = /mcx_sess=([^;]+)/.match(result.headers['set-cookie'])
        key_match = /mcx_key=([^;]+)/.match(result.headers['set-cookie'])
        if session_match && key_match
          @key = key_match.captures.first
          @session = session_match.captures.first
          logged_in = true
        else
          log "Login fail"
        end
        logged_in
      end

    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Mcxnow", "thread" => Thread.new do
  WarpBubble::Exchanges::Mcxnow.new.go
end})

