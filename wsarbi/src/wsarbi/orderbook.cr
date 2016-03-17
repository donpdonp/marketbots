module Wsarbi
  class Orderbook
    getter :bids, :asks

    def initialize
      @bids = Market.new(Market::BidAsk::Bid)
      @asks = Market.new(Market::BidAsk::Ask)
    end

    def profitables
      good_asks = [] of Offer
      good_bids = [] of Offer
      if @bids.offers.size > 0 && @asks.offers.size > 0
        good_asks += @asks.better_than(@bids.best.price)
        good_bids += @bids.better_than(@asks.best.price)
      end
      { good_asks, good_bids }
    end
  end
end
