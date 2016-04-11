# system
require "yaml"
require "json"
require "http"

# shards
require "redis"

# local
require "./src/wsarbi"

shard = YAML.parse(File.read("shard.yml"))
config = JSON.parse(File.read("config.json"))
puts "wsarbi #{shard["version"]}"

redis = Redis.new
orderbook = Wsarbi::Orderbook.new

# btc price spot
response = HTTP::Client.get "https://blockchain.info/q/24hrprice"
btc_usd = response.body.to_f
puts "BTC price set to $#{btc_usd}"

# Blocking subscribe
redis.subscribe("orderbook") do |on|
  on.message do |channel, json|
    begin
      msg = JSON.parse(json)
      if msg["type"].as_s == "bid" || msg["type"].as_s == "ask"
        puts "* #{msg["exchange"].as_s} #{msg["market"].as_s} #{msg["type"].as_s} #{msg["price"].as_s} x#{msg["amount"].as_s}"
      else
        puts "* #{msg["type"].as_s}"
      end
      if msg["type"] == "bid"
        orderbook.bids.add(Wsarbi::Offer.new(
          msg["exchange"].as_s,
          msg["market"].as_s,
          msg["price"].as_s,
          msg["amount"].as_s
        ))
      end
      if msg["type"] == "ask"
        orderbook.asks.add(Wsarbi::Offer.new(
          msg["exchange"].as_s,
          msg["market"].as_s,
          msg["price"].as_s,
          msg["amount"].as_s
        ))
      end
      if msg["type"] == "load"
        exchange_name = msg["exchange"].as_s
        ask_drop_count = orderbook.asks.clear(exchange_name)
        bid_drop_count = orderbook.bids.clear(exchange_name)
        puts "* cleared #{exchange_name} #{ask_drop_count} #{bid_drop_count}"
        msg["asks"].each do |ask|
          orderbook.asks.add(Wsarbi::Offer.new(
            msg["exchange"].as_s,
            msg["market"].as_s,
            ask["price"].as_s,
            ask["amount"].as_s
          ))
        end
        msg["bids"].each do |ask|
          orderbook.bids.add(Wsarbi::Offer.new(
            msg["exchange"].as_s,
            msg["market"].as_s,
            ask["price"].as_s,
            ask["amount"].as_s
          ))
        end
        puts "*  loaded #{exchange_name} #{msg["asks"].size} #{msg["bids"].size}"
      end

      puts "Orderbook asks #{orderbook.asks.bins[0]}"
      puts "               #{orderbook.asks.bins[1]}" if orderbook.asks.size > 1
      puts "               #{orderbook.asks.bins.last}" if orderbook.asks.size > 2
      puts "          bids #{orderbook.bids.bins[0]}"
      puts "               #{orderbook.bids.bins.[1]}" if orderbook.bids.size > 1
      puts "               #{orderbook.bids.bins.last}" if orderbook.bids.size > 2
      if orderbook.asks.size > 0 && orderbook.bids.size > 0
        low_ask = orderbook.asks.bins.first.offers.first
        high_bid = orderbook.bids.bins.first.offers.first
        if low_ask.price.to_f < high_bid.price.to_f
          # puts "*!* INVERSION ask #{low_ask.exchange} bid #{high_bid.exchange}"
          if low_ask.exchange == high_bid.exchange
            puts "!!! Orderbook error"
          end
        end
      end

      win_bid, win_ask = orderbook.profitables
      if win_bid.size > 0 || win_ask.size > 0
        puts "arb winning #{win_bid.size} bids #{win_bid.summary}"
        puts "arb winning #{win_ask.size} asks #{win_ask.summary}"
        puts "arbcheck  asks #{win_ask.bins.first}"
        puts "          last #{win_ask.bins.last}" if win_ask.size > 1
        puts "          bids #{win_bid.bins.first}"
        puts "          last #{win_bid.bins.last}" if win_bid.size > 1
      end
      orders = orderbook.arbitrage(win_bid, win_ask)
      if orders.keys.size > 0
        puts orders.inspect
        orders.each do |pair, order|
          spent = order[:amount] * order[:buy_price]
          earned = order[:amount] * order[:sell_price]
          profit = earned - spent
          profit_percent = profit/spent*100
          profit_after_fee = earned * (1 - 0.0025) - spent * (1 + 0.0025)
          profit_after_fee_percent = profit_after_fee / (spent * (1 + 0.0025)) * 100
          alert = "#{"%0.2f" % (profit_after_fee*btc_usd)}usd " +
            "#{"%0.2f" % profit_after_fee_percent}% " +
            "#{Time.now.to_s("%Y-%m-%d %H:%M:%S")} " +
            "#{pair} spent #{"%0.3f" % spent}btc #{"%0.1f" % order[:amount]}eth " +
            "profit #{"%0.8f" % profit}btc #{"%0.2f" % (profit*btc_usd)}usd" +
            " #{"%0.2f" % profit_percent}% "
          puts alert
          # redis.lpush("wsarbi:signals", alert)
          if profit_percent >= config["signal_percentage"].as_f
            File.open("signal.log", "a") do |f|
              f.puts "#{alert}"
            end
            redis.set("wsarbi:plan", orders.to_json)
          end
        end
      end
    end
  end
end
