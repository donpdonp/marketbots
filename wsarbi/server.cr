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
      puts msg.inspect
      if msg["type"] == "bid"
        orderbook.bids.add([Wsarbi::Offer.new(
          msg["exchange"].as_s,
          msg["market"].as_s,
          msg["price"].as_s.to_f,
          msg["amount"].as_s.to_f
          )])
      end
      if msg["type"] == "ask"
        orderbook.asks.add([Wsarbi::Offer.new(
          msg["exchange"].as_s,
          msg["market"].as_s,
          msg["price"].as_s.to_f,
          msg["amount"].as_s.to_f
          )])
      end
      win_ask, win_bid = orderbook.profitables
      puts "Orderbook asks #{orderbook.asks.offers.size} bids #{orderbook.bids.offers.size}"
      win_ask_value = win_ask.reduce(0){|m,o| m + (o.price * o.quantity)}
      win_bid_value = win_bid.reduce(0){|m,o| m + (o.price * o.quantity)}
      puts "Arbitrage ask value #{win_ask_value} #{win_ask.map(&.exchange).uniq} bid value #{win_bid_value} #{win_bid.map(&.exchange).uniq}"
      # win_ask.each do |o|
      #   puts "      ASK |#{o.exchange}| #{o.price} x#{o.quantity}"
      # end
      # win_bid.each do |o|
      #   puts "      BID |#{o.exchange}| #{o.price} x#{o.quantity}"
      # end

    rescue ex
      puts ex.message
      puts json.inspect
    end
  end
end
