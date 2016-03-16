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
redis.subscribe("exchanges") do |on|
  on.message do |channel, json|
    begin
      msg = JSON.parse(json)
      puts msg.inspect
      # orderbook.asks.add([o2])
      # orderbook.bids.add([o1])
      winners = orderbook.profitables
      puts winners.inspect
    rescue ex
      puts ex.message
      puts json.inspect
    end
  end
end
