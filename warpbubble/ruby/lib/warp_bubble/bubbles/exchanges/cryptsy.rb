require 'time'

class WarpBubble
  class Exchanges
    class Cryptsy < Base

      @@short_name = 'cryptsy'
      @@api_url = "https://www.cryptsy.com/api"

      def initialize
        super(@@short_name)
      end

      def balance_refresh(payload)
        balances = post('getinfo')
        @balances = {}
        balances["balances_available"].each{|key, value| @balances[key.downcase] = value.to_f }
        msg = "balance refresh. #{"%0.8f"% @balances['ltc']} ltc. "+
              "#{"%0.8f"% @balances['btc']} btc. "+
              "#{balances["openordercount"]} open orders"
        log(msg)
        blnce = { type: 'Exchange#balance',
                  time: Time.at(balances["servertimestamp"]).iso8601,
                  object: @balances }
        @chan_pub.set("warpbubble:balance:#{@@short_name}", blnce.to_json)
      end

      def order(payload)
        order_detail = {'marketid' => 3, #LTC/BTC
                        'ordertype' => payload['order'],
                        'price' => payload['price'],
                        'quantity' => payload['quantity']}
        log "ORDER GO #{order_detail}"
        post('createorder', order_detail)
        super
      end

      def order_drop(payload)
        log "Order Drop!"
        cancels = post('cancelallorders')
        log "Cancelled #{cancels}"
      end

      def post(command, params = {})
        params["method"] = command
        params["nonce"] = Time.now.to_i.to_s
        headers = {'Key' => @api_key, 'Sign' => sign(params)}
        result = HTTParty.post @@api_url, {:body => params, :headers => headers, :format => :json}
        if result.parsed_response["success"] == "1"
          result.parsed_response["return"]
        else
          log result.parsed_response.inspect
        end
      end

      def login
        log "logging in with #{@chan_pub.get("#{@@short_name}:username")}"
        web_driver.navigate.to "https://www.cryptsy.com/users/login"
        element = web_driver.find_element(:id, 'UserUsername')
        element.send_keys @chan_pub.get("#{@@short_name}:username")
        element = web_driver.find_element(:id, 'UserPassword')
        element.send_keys @chan_pub.get("#{@@short_name}:password")
        element.submit
        puts web_driver.title
        # wait for a specific element to show up
        wait = Selenium::WebDriver::Wait.new(:timeout => 10) # seconds
        wait.until { web_driver.find_element(:class => "messages") }
        element = web_driver.find_element(:class, 'messages')
        element.text == "You have been successfully logged in"
      end

      def transfer(payload)
        currency = payload["currency"]
        amount = trim_float(payload["amount"],8)
        address = payload["address"]
        if login
          log 'Login Success!'
          marketid = "2" if currency == 'ltc'
          marketid = "3" if currency == 'btc'
          web_driver.navigate.to "https://www.cryptsy.com/users/makewithdrawal/#{marketid}"
          web_driver.save_screenshot('market1.png')
          element = web_driver.find_element(:id, 'WithdrawalAddress')
          element.send_keys address
          element = web_driver.find_element(:id, 'WithdrawalExistingPassword')
          element.send_keys @chan_pub.get("#{@@short_name}:password")
          element = web_driver.find_element(:id, 'WithdrawalWdamount')
          log "amount #{amount.to_s}"
          element.send_keys ("\b"*10)+amount.to_s
          web_driver.save_screenshot('market2.png')
          element.submit
          web_driver.save_screenshot('market3.png')
          puts web_driver.title
        else
          log element.text
        end
      end

      def email_confirm(payload)
        username = @chan_pub.get("#{@@short_name}:username")
        links = mailinator(username, /Confirm Your Withdrawal/, /confirmwithdrawal/)
        if links.size == 1
          confirm_url = links.first.attribute('href')
          if login
            log "confirming #{confirm_url}"
            web_driver.navigate.to(confirm_url)
          else
            log 'email confirm, login failed'
          end
        else
          log 'email confirm not found'
        end
      end

    end
  end
end

WarpBubble.add_service({"name" => "Exchanges::Cryptsy", "thread" => Thread.new do
  WarpBubble::Exchanges::Cryptsy.new.go
end})

