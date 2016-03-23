require "../spec_helper"

module Wsarbi
  describe "Orderbook" do
    subject = Orderbook.new

    bids = [
      Offer.new("shareco", "btc_usd", "1.5", "1.0"),
      Offer.new("shareco", "btc_usd", "1.0", "1.0"),
    ]

    asks = [
      Offer.new("shareco", "btc_usd", "1.0", "1.0"),
      Offer.new("shareco", "btc_usd", "1.5", "1.0"),
      Offer.new("shareco", "btc_usd", "2.0", "1.0"),
    ]

    it "remembers price and quantity" do
      bids.each do |bid|
        subject.bids.add(bid)
      end
      asks.each do |ask|
        subject.asks.add(ask)
      end
      good_bids, good_asks, profits = subject.profitables
      good_asks.bins.size.should eq(1)
      good_asks.bins.first.price.to_s.should eq("1.0000")
    end
  end
end
