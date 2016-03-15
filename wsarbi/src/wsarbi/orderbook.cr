module Wsarbi
  class Orderbook
    getter :bids, :asks

    def initialize
      @bids = Market.new(Market::BidAsk::Bid)
      @asks = Market.new(Market::BidAsk::Ask)
    end

    def profitables
      if @bids.offers.size > 0
        bid_price = @bids.best.price
        @asks.better_than(bid_price)
      else
        [] of Offer
      end
    end
  end
end
