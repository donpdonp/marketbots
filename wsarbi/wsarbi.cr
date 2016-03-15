require "./src/wsarbi"

puts "wsarbi"

orderbook = Wsarbi::Orderbook.new
o1 = Wsarbi::Offer.new(2.0, 1.0)
o2 = Wsarbi::Offer.new(1.0, 1.0)

# market_pool.add(market)
# market_pool.add(market)

orderbook.bids.add([o1])
orderbook.asks.add([o2])
winners = orderbook.profitables
puts winners.inspect
