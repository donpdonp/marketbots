# system
require "yaml"
require "json"

# shards
require "redis"

# local
require "./src/wsarbi"

shard = YAML.parse(File.read("shard.yml"))
config = JSON.parse(File.read("config.json"))
puts "wsarbi #{shard["version"]}"

redis = Redis.new
orderbook = Wsarbi::Orderbook.new

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
        spent = orders.reduce(0) { |memo, exch, order| memo + order[:amount] * order[:buy_price] }
        earned = orders.reduce(0) { |memo, exch, order| memo + order[:amount] * order[:sell_price] }
        profit = earned - spent
        profit_percent = profit/spent*100
        puts "spent #{spent} earned #{earned} profit #{"%0.8f" % profit}/$#{"%0.2f" % (profit*420)} #{"%0.2f" % profit_percent}%"
        if profit_percent >= config["signal_percentage"].as_f
          low_ask = orderbook.asks.best.offers.first
          high_bid = orderbook.bids.best.offers.first
          File.open("signal.log", "a") do |f|
            f.puts "#{Time.now} spent #{spent} earned #{earned} profit #{"%0.8f" % profit}btc #{"%0.2f" % profit_percent}% $#{"%0.2f" % (profit*420)}"
          end
          puts "Arbitrage ask value #{"%0.8f" % win_ask.value}btc  bid value #{"%0.8f" % win_bid.value}btc"
        end
      end
    end
  end
end
