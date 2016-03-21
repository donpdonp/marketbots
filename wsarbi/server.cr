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
      puts "* #{msg["exchange"].as_s} #{msg["market"].as_s} #{msg["type"].as_s} #{msg["price"].as_s} x#{msg["amount"].as_s}"
      if msg["type"] == "bid"
        orderbook.bids.add(Wsarbi::Offer.new(
          msg["exchange"].as_s,
          msg["market"].as_s,
          msg["price"].as_s.to_f,
          msg["amount"].as_s.to_f
        ))
      end
      if msg["type"] == "ask"
        orderbook.asks.add(Wsarbi::Offer.new(
          msg["exchange"].as_s,
          msg["market"].as_s,
          msg["price"].as_s.to_f,
          msg["amount"].as_s.to_f
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
      win_ask, win_bid = orderbook.profitables
      puts "Orderbook asks #{orderbook.asks.summary}"
      puts "          bids #{orderbook.bids.summary}"
      win_ask_value = win_ask.reduce(0) { |m, ob| m + ob.value }
      win_bid_value = win_bid.reduce(0) { |m, ob| m + ob.value }
      unless win_ask_value == 0 && win_bid_value == 0
        arb_total = Math.min(win_ask_value, win_bid_value)
        puts "#### ARBITRAGE #{"%0.3f" % arb_total}btc"
        puts "Arbitrage ask value #{win_ask_value}btc  bid value #{win_bid_value}btc"
        win_ask.each do |ob|
          puts "      ASK |#{ob.exchanges}| bin #{ob.price} x#{ob.quantity}"
          ob.offers.each do |o|
            puts "            offer #{o.exchange} ask #{o.price} x#{o.quantity}"
          end
        end
        win_bid.each do |ob|
          puts "      BID |#{ob.exchanges}| bin #{ob.price} x#{ob.quantity}"
          ob.offers.each do |o|
            puts "            offer #{o.exchange} bid #{o.price} x#{o.quantity}"
          end
        end
      end
    rescue ex
      puts ex.message
      puts json.inspect
    end
  end
end
