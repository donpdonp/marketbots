module Wsarbi
  class Orderbook
    getter :bids, :asks

    def initialize
      @bids = Market.new(Market::BidAsk::Bid, 0.0001)
      @asks = Market.new(Market::BidAsk::Ask, 0.0001)
    end

    def profitables
      good_asks = Market.new(Market::BidAsk::Ask, 0.0001)
      good_bids = Market.new(Market::BidAsk::Bid, 0.0001)

      good_asks.add(@asks.better_than(@bids.best.price)) if @bids.size > 0
      good_bids.add(@bids.better_than(@asks.best.price)) if @asks.size > 0

      {good_bids, good_asks}
    end

    def arbitrage(bids : Market, asks : Market)
      purse = asks.quantity
      bids.bins.reduce(0) do |m, bid_ob|
        spend = Math.min(purse, bid_ob.quantity)
        purse -= spend
        m + bid_ob.price.to_f * spend
      end
    end
  end
end
