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
      if msg["type"] == "clear"
        exchange_name = msg["exchange"].as_s
        ask_drop = orderbook.asks.clear(exchange_name)
        bid_drop = orderbook.bids.clear(exchange_name)
        puts "********"
        puts "CLEARED #{exchange_name} #{ask_drop} #{bid_drop}"
        puts "********"
      end
      puts "Orderbook asks #{orderbook.asks.bins[0]}"
      puts "               #{orderbook.asks.bins[1]}"
      puts "          bids #{orderbook.bids.bins[0]}"
      puts "               #{orderbook.bids.bins[1]}"
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
        puts "arb winning bids #{win_bid.summary}"
        puts "arb winning asks #{win_ask.summary}"
      end
      spend = win_ask.value
      earn = orderbook.arbitrage(win_bid, win_ask)
      profit = earn - spend
      profit_percent = profit/spend*100
      if profit_percent >= 0.1
        low_ask = orderbook.asks.bins.first.offers.first
        high_bid = orderbook.bids.bins.first.offers.first
        puts "#### ARBITRAGE #{"%0.8f" % profit}btc #{"%0.2f" % (profit_percent)}% of #{spend}btc buy #{low_ask.exchange} sell #{high_bid.exchange}"
        File.open("arb.out", "a") { |f| f.puts "#{Time.now} #{"%0.8f" % profit}btc #{"%0.2f" % (profit/spend*100)}% of #{spend}" }
        puts "Arbitrage ask value #{"%0.8f" % win_ask.value}btc  bid value #{"%0.8f" % win_bid.value}btc"
        win_ask.bins.each do |ob|
          puts "      ASK |#{ob.exchanges}| bin #{ob.price.to_s} x#{ob.quantity}"
          # ob.offers.each do |o|
          #   puts "            offer #{o.exchange} ask #{o.price.to_s} x#{o.quantity.to_f.to_i}"
          # end
        end
        win_bid.bins.each do |ob|
          puts "      BID |#{ob.exchanges}| bin #{ob.price} x#{ob.quantity}"
          # ob.offers.each do |o|
          #   puts "            offer #{o.exchange} bid #{o.price} x#{o.quantity.to_f.to_i}"
          # end
        end
      end
    rescue ex
      ex.backtrace.each { |t| puts t }
      puts ex.message
      puts json.inspect
    end
  end
end
