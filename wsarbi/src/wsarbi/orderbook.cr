module Wsarbi
  class Orderbook
    getter :bids, :asks

    def initialize
      puts "New Orderbook"
      @bids = Market.new(Market::BidAsk::Bid)
      @asks = Market.new(Market::BidAsk::Ask)
    end

    def profitables
      bid_price = @bids.best.price
      @asks.better_than(bid_price)
    end
  end
end
