require "../spec_helper"

module Wsarbi
  describe "Offer" do
    it "remembers price and quantity" do
      offer = Wsarbi::Offer.new("shareco", "btc_usd", "1.0", "2.0")
      offer.price.to_s.should eq("1.00000000")
      offer.quantity.to_s.should eq("2.00000000")
    end
  end
end
