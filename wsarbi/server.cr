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
      if msg["type"].as_s == "bid"
        puts "* #{msg["exchange"].as_s} #{msg["market"].as_s} #{msg["type"].as_s} #{msg["price"].as_s} x#{msg["amount"].as_s}"
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
      if msg["type"] == "clear"
        exchange_name = msg["exchange"].as_s
        ask_drop = orderbook.asks.clear(exchange_name)
        bid_drop = orderbook.bids.clear(exchange_name)
        puts "********"
        puts "CLEARED #{exchange_name} #{ask_drop} #{bid_drop}"
        puts "********"
      end
      puts "Orderbook asks #{orderbook.asks.summary}"
      puts "          bids #{orderbook.bids.summary}"
      win_bid, win_ask = orderbook.profitables
      puts "good bids #{win_bid.bins.size} good asks #{win_ask.bins.size}"
      arb_total = orderbook.arbitrage(win_bid, win_ask)
      if arb_total > 0
        puts "#### ARBITRAGE #{"%0.4f" % arb_total}btc"
        puts "Arbitrage ask value #{win_ask.value}btc  bid value #{win_bid.value}btc"
        win_ask.bins.each do |ob|
          puts "      ASK |#{ob.exchanges}| bin #{ob.price.to_s} x#{ob.quantity}"
          ob.offers.each do |o|
            puts "            offer #{o.exchange} ask #{o.price.to_s} x#{o.quantity.to_f.to_i}"
          end
        end
        win_bid.bins.each do |ob|
          puts "      BID |#{ob.exchanges}| bin #{ob.price} x#{ob.quantity}"
          ob.offers.each do |o|
            puts "            offer #{o.exchange} bid #{o.price} x#{o.quantity.to_f.to_i}"
          end
        end
      end
    rescue ex
      ex.backtrace.each { |t| puts t }
      puts ex.message
      puts json.inspect
    end
  end
end
