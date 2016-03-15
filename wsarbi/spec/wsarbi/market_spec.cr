require "../spec_helper"

module Wsarbi
  describe "Market" do
    describe "Bid Market" do
      bids = [
        Offer.new(1.0, 1.0),
        Offer.new(2.0, 1.0),
        Offer.new(1.5, 1.0),
      ]

      it "keeps offers sorted" do
        bid_market = Market.new(Market::BidAsk::Bid)
        bid_market.add(bids)
        bid_market.best.price.should eq(2.0)
      end
    end

    describe "Ask Market" do
      asks = [
        Offer.new(2.0, 1.0),
        Offer.new(1.0, 1.0),
        Offer.new(1.5, 1.0),
      ]

      it "keeps offers sorted" do
        ask_market = Market.new(Market::BidAsk::Ask)
        ask_market.add(asks)
        ask_market.best.price.should eq(1.0)
      end
    end
  end
end
