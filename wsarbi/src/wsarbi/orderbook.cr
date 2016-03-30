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
      bids = bid_market.offers.map(&.dup_worksheet)
      asks = ask_market.offers.map(&.dup_worksheet)
      orders = {} of String => Hash(Symbol, Float64)
      asks.each do |ask_ws|
        bids.each do |bid_ws|
          selling = Math.min(ask_ws.remaining, bid_ws.offer.quantity.to_f)
          ask_ws.remaining -= selling
          bid_ws.remaining -= selling
          pair = "#{ask_ws.exchange}:#{bid_ws.exchange}"
          order = orders[pair] ||= {amount: 0.0, buy_price: 0.0, sell_price: 0.0}
          order[:amount] += selling
          order[:buy_price] = ask_ws.price  # highest price
          order[:sell_price] = bid_ws.price # lowest price
        end
      end
      orders
    end
  end
end
