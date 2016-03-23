require "../spec_helper"

module Wsarbi
  describe "OfferBin" do
    it "remembers price and quantity" do
      bin = Wsarbi::OfferBin.new(FauxDecimal.new("1.0", 4), 4)
      bin.price.to_s.should eq("1.0000")
      bin.offers.size.should eq(0)
    end
  end
end
