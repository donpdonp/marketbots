module Wsarbi
  class Orderbook
    getter :bids, :asks

    def initialize
      @bids = Market.new(Market::BidAsk::Bid, 0.0001)
      @asks = Market.new(Market::BidAsk::Ask, 0.0001)
    end

    def profitables
      good_asks = [] of OfferBin
      good_bids = [] of OfferBin
      if @bids.bins.size > 0 && @asks.bins.size > 0
        good_asks += @asks.better_than(@bids.best.price)
        good_bids += @bids.better_than(@asks.best.price)
      end
      { good_asks, good_bids }
    end
  end
end
