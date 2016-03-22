require "../spec_helper"

module Wsarbi
  describe "Market" do
    describe "Bid Market" do
      subject = Market.new(Market::BidAsk::Bid, 0.0001)

      bids = [
        Offer.new("shareco", "btc_usd", "1.0", "1.0"),
        Offer.new("shareco", "btc_usd", "2.0", "1.0"),
        Offer.new("shareco", "btc_usd", "1.5", "1.0"),
      ]

      it "sorts high to low" do
        bids.each do |bid|
          subject.add(bid)
        end
        subject.best.price.to_s.should eq("2.0000")
      end
    end

    describe "Ask Market" do
      subject = Market.new(Market::BidAsk::Ask, 0.0001)

      asks = [
        Offer.new("shareco", "btc_usd", "2.0", "1.0"),
        Offer.new("shareco", "btc_usd", "1.0", "1.0"),
        Offer.new("shareco", "btc_usd", "1.5", "1.0"),
      ]

      it "sort low to high" do
        asks.each do |ask|
          subject.add(ask)
        end
        subject.best.price.to_s.should eq("1.0000")
      end

      it "clears offers for an exchange" do
        subject.clear("shareco")
      end
    end

    it "decides on a bin for a price" do
      subject = Market.new(Market::BidAsk::Bid, 0.0001)
      subject.bin_price_for(FauxDecimal.new("0.123456", 4)).to_s.should eq("0.1234")
    end

    it "doesnt float around" do
      # * poloniex ETH:BTC ask 0.02839999 x49.43663712
      # bin 0.0283/0 adding offer 0.0284
      "0.02839999".to_f.should eq(0.02839999)
      # puts "%0.8f" % 0.02839999 => "0.02839999"
      # puts 0.02839999 => "0.0284"
    end
  end
end
