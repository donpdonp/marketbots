require "selenium-webdriver"

class WarpBubble
  class Exchanges
    class Base < WarpBubble::Base

      @@driver = Selenium::WebDriver.for(:remote, :url => "http://localhost:8910")

      def initialize(short_name)
        super()
        @short_name = short_name
        del("warpbubble:balance:#{short_name}")
        @api_key = @chan_pub.get("#{short_name}:key")
        @api_secret = @chan_pub.get("#{short_name}:secret")
        unless @api_key && @api_secret
          log("Warning: no API Key")
        end
      end

      def go
        @chan_sub.subscribe(@@channel_name) do |on|
          on.subscribe do |channel, count|
            publish({"action" => "exchange ready", "payload" => {"exchange" => @short_name}})
          end

          on.message do |channel, json|
            message = JSON.parse(json)
            if message['payload'] && (message['payload']['exchange'] == @short_name ||
                                      message['payload']['exchange'] == "*")
              case message["action"]
              when "exchange balance"
                balance(message["payload"])
              when "balance refresh", "exchange ready"
                balance_refresh(message["payload"])
              when "order"
                order(message["payload"])
              when "order drop"
                order_drop(message["payload"])
              when "transfer"
                transfer(message["payload"])
              when "email check"
                email_confirm(message["payload"])
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
        publish({"action" => "order complete", "payload" => {"exchange" => @short_name,
                                                             "balances" => @balances}})
      end

      def sign(params)
        hmac = OpenSSL::HMAC.new(@api_secret, OpenSSL::Digest::SHA512.new)
        hmac.update(URI.encode_www_form(params)).to_s
      end

      def trim_float(float, count)
        int, dec = float.to_s.split('.')
        int.to_i+("0."+dec[0,count]).to_f
      end

      def web_driver
        @@driver
      end

      def mailinator(username, title_words, link_words)
        url = "http://www.mailinator.com/feed?to=#{username}"
        resp = HTTParty.get(url, {:format => :xml})
        items = resp.parsed_response["RDF"]["item"]
        if items
          items = [items] unless items.is_a?(Array)
          confirm_email = items.select{|i| i["title"].match(title_words)}.last
          if confirm_email
            @@driver.navigate.to(confirm_email["rdf:about"])
            @@driver.find_elements(:css, 'div.mailview a').reject do |link|
              link.attribute('href').match(link_words)
            end
          else
            log "no confirmation mail for #{url}"
            []
          end
        else
          log "no mail for #{url}"
          []
        end
      end

    end
  end
end