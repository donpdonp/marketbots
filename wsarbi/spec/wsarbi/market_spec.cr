require "../spec_helper"

module Wsarbi
  describe "Market" do
    describe "Bid Market" do
      bids = [
        Offer.new(1.0, 1.0),
        Offer.new(2.0, 1.0),
        Offer.new(1.5, 1.0),
      ]

      it "remembers price and quantity" do
        bid_market = Wsarbi::Market.new(Wsarbi::Market::BidAsk::Bid)
        bid_market.add(bids)
        bid_market.best
      end
    end

    describe "Ask Market" do
      asks = [
        Offer.new(1.0, 1.0),
        Offer.new(2.0, 1.0),
        Offer.new(1.5, 1.0),
      ]

      it "remembers price and quantity" do
        ask_market = Wsarbi::Market.new(Wsarbi::Market::BidAsk::Ask)
        ask_market.add(asks)
        ask_market.best
      end
    end
  end
end
