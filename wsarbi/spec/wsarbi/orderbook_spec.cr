require "../spec_helper"

module Wsarbi
  describe "Orderbook" do
    subject = Orderbook.new

    bids = [
      Offer.new(1.5, 1.0),
      Offer.new(1.0, 1.0),
    ]

    asks = [
      Offer.new(1.0, 1.0),
      Offer.new(1.5, 1.0),
      Offer.new(2.0, 1.0),
    ]

    it "remembers price and quantity" do
      subject.bids.add(bids)
      subject.asks.add(asks)
      subject.profitables.size.should eq(1)
    end
  end
end
