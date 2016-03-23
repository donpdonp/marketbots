require "../spec_helper"

module Wsarbi
  describe "Orderbook" do
    bids = [
      Offer.new("shareco", "btc_usd", "1.5", "1.0"),
      Offer.new("shareco", "btc_usd", "1.0", "1.0"),
    ]

    asks = [
      Offer.new("shareco", "btc_usd", "1.0", "1.0"),
      Offer.new("shareco", "btc_usd", "1.5", "1.0"),
      Offer.new("shareco", "btc_usd", "2.0", "1.0"),
    ]

    it "identifies asks below bids and vice versa" do
      subject = Orderbook.new
      bids.each do |bid|
        subject.bids.add(bid)
      end
      asks.each do |ask|
        subject.asks.add(ask)
      end
      good_bids, good_asks = subject.profitables
      good_asks.bins.size.should eq(1)
      good_asks.bins.first.price.to_s.should eq("1.0000")
      good_bids.bins.size.should eq(1)
      good_bids.bins.first.price.to_s.should eq("1.5000")
    end

    it "calculates profit between markets" do
      subject = Orderbook.new
      bids.each do |bid|
        subject.bids.add(bid)
      end
      asks.each do |ask|
        subject.asks.add(ask)
      end
      good_bids, good_asks = subject.profitables
      earn = subject.arbitrage(good_bids, good_asks)
      earn.should eq(1.5)
    end
  end
end
