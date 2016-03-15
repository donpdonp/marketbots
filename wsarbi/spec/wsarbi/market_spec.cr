require "../spec_helper"

module Wsarbi
  describe "Market" do
    describe "Bid Market" do
      subject = Market.new(Market::BidAsk::Bid)

      bids = [
        Offer.new(1.0, 1.0),
        Offer.new(2.0, 1.0),
        Offer.new(1.5, 1.0),
      ]

      it "find the best offer" do
        subject.add(bids)
        subject.best.price.should eq(2.0)
      end
    end

    describe "Ask Market" do
      subject = Market.new(Market::BidAsk::Ask)

      asks = [
        Offer.new(2.0, 1.0),
        Offer.new(1.0, 1.0),
        Offer.new(1.5, 1.0),
      ]

      it "find the best offer" do
        subject.add(asks)
        subject.best.price.should eq(1.0)
      end
    end
  end
end
