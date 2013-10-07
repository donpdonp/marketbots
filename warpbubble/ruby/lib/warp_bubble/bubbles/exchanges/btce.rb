class WarpBubble
  class Exchanges
    class Btce < Exchanges::Base

      @@short_name = 'btce'
      @@api_url = "https://btc-e.com/tapi"

      def initialize
        super(@@short_name)
      end

      def balance_refresh(payload)
        @balances = post('getInfo')
        msg = "balance refresh. #{"%0.8f"% @balances['funds']['ltc']} ltc. "+
              "#{"%0.8f"% @balances['funds']['btc']} btc. "+
              "#{@balances["open_orders"]} open orders"
        log(msg)
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

      def order_drop(payload)
        log "Order Drop!"
        orders = post('ActiveOrders')
        orders.each do |id, detail|
          log "Cancelling order #{detail['pair']} x#{detail['amount']}"
          post('CancelOrder', {'order_id' => id})
        end
        super
      end

      def post(command, params = {})
        params["method"] = command
        # btc-e nonce capped at unixtime.
        nonce = params["nonce"] || @chan_pub.get("#{@@short_name}:nonce").to_i
        @chan_pub.set("#{@@short_name}:nonce", nonce+1)
        params["nonce"] = nonce
        headers = {'Key' => @api_key, 'Sign' => sign(params)}
        result = HTTParty.post @@api_url, {:body => params, :headers => headers, :format => :json}
        if result.parsed_response["success"] == 1
          result.parsed_response["return"]
        else
          # more noncesense
          match = /invalid nonce.*on key:(\d+)/.match(result.parsed_response["error"])
          if match
            params["nonce"] = match[1].to_i+1
            log "nonce readjusted to #{params["nonce"]} and retrying."
            post(command, params) #do it again
          else
            log result.parsed_response.inspect
          end
        end
      end

      def login
        email = @chan_pub.get("#{@@short_name}:username")
        username = email.split('@').first
        password = @chan_pub.get("#{@@short_name}:password")
        logged_in = false
        log "https://btc-e.com #{username}"
        web_driver.navigate.to "https://btc-e.com"
        elements = web_driver.find_elements(:class, 'profile')
        if elements.size == 1 && elements.first.text.split.first == username
          log 'Already logged in!'
          logged_in = true
        else
          log "logging in with #{email}"
          element = web_driver.find_element(:id, 'email')
          element.send_keys email
          element = web_driver.find_element(:id, 'password')
          element.send_keys password
          element.submit
          log web_driver.title
          wait = Selenium::WebDriver::Wait.new(:timeout => 10) # seconds
          wait.until { web_driver.find_element(:class => "profile") }
          element = web_driver.find_element(:class, 'profile')
          if element.text.split.first == username
            log 'Login Success!'
            logged_in = true
          else
            log "Login fail: #{element.text.split.first}"
          end
        end
        logged_in
      end

      def transfer(payload)
        currency = payload["currency"]
        amount = payload["amount"]
        address = payload["address"]
        log "transfer #{amount} #{currency} to #{address}"
        logged_in = login
        if logged_in
          profile = web_driver.find_elements(:css, "div.profile a").select{|b| b.attribute("href") == "https://btc-e.com/profile#funds"}.first
          if profile
            profile.click
            log web_driver.title
            market_id = 1 if currency == 'btc'
            market_id = 8 if currency == 'ltc'
            market_url = "https://btc-e.com/profile#funds/withdraw_coin/#{market_id}"
            buttons = web_driver.
                        find_elements(:css, "a").
                            select{|b|
                              b.attribute("href") == market_url}
            if buttons.size == 1
              xfer_button = buttons.first
              xfer_button.click
              log "#{currency} withdrawal button pushed"
              wait = Selenium::WebDriver::Wait.new(:timeout => 10) # seconds
              wait.until { web_driver.find_element(:css => 'div#billing h1') }
              element = web_driver.find_element(:css, 'div#billing h1')
              if element.text == "Withdrawal #{currency.upcase}"
                log 'withdrawal form found.'
                element = web_driver.find_element(:id, 'address')
                element.send_keys address
                element = web_driver.find_element(:id, 'sum')
                element.send_keys amount.to_s
                withdrawal_buttons = web_driver.find_elements(:css, 'a').select{|b| b.attribute('onClick') == "withdraw_coin(#{market_id});"}
                if withdrawal_buttons.size == 1
                  log "#{amount}#{currency} withdrawl click"
                  withdrawal_buttons.first.click
                end
              end
            else
              log 'transfer button not found'
            end
          else
            log 'No profile button found'
          end
        end
        web_driver.close
      end

      def email_confirm(payload)
        email = @chan_pub.get("#{@@short_name}:username")
        username = email.split('@').first
        links = mailinator(username, /Withdraw confirmation/, /cancel/)
        if links.size == 1
          log 'email confirm link found'
          confirm_url = links.first.attribute('href')
          if login
            log 'confirming'
            web_driver.navigate.to(confirm_url)
          end
        else
          log 'email confirm not found'
        end
      end

    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Btce", "thread" => Thread.new do
  WarpBubble::Exchanges::Btce.new.go
end})

