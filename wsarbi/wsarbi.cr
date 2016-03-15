require "./src/wsarbi"

puts "wsarbi"

orderbook = Wsarbi::Orderbook.new
market = Wsarbi::Market.new
o1 = Wsarbi::Offer.new
o2 = Wsarbi::Offer.new

# market_pool.add(market)
# market_pool.add(market)

orderbook.add_bids([o1])
orderbook.add_asks([o2])

# orderbook.profitable_asks => [ask]
# orderbook.profitable_bids => [bid]
