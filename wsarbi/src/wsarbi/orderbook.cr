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
      good_asks.add(@asks.better_than(@bids.best.price))
      good_bids.add(@bids.better_than(@asks.best.price))

      {good_bids, good_asks, arbitrage(good_bids, good_asks)}
    end

    def arbitrage(bids : Market, asks : Market)
      starting = asks.value
      purse = asks.quantity
      remaining = bids.bins.reduce(0) do |m, bid_ob|
        spend = Math.min(purse, bid_ob.quantity)
        purse -= spend
        m + bid_ob.price.to_f * spend
      end
      starting - remaining
    end
  end
end
