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

    def arbitrage(bid_market : Market, ask_market : Market)
      bids = bid_market.offers.map { |bo| {price: bo.price.to_f, quantity: bo.quantity.to_f} }
      asks = ask_market.offers.map { |ao| {price: ao.price.to_f, quantity: ao.quantity.to_f} }
      purse = 0.0
      earned = 0.0
      spent = asks.reduce(0) do |spent, ask_of|
        start_qty = ask_of[:quantity]
        earn = bids.reduce(0) do |earned, bid_of|
          selling = Math.min(ask_of[:quantity], bid_of[:quantity])
          ask_of[:quantity] -= selling
          bid_of[:quantity] -= selling
          earned + bid_of[:price] * selling
        end
        earned += earn
        spent + ask_of[:price] * (start_qty - ask_of[:quantity])
      end
      {spent, earned}
    end
  end
end
