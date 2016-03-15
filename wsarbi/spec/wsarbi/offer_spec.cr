require "../spec_helper"

module Wsarbi
  describe "Offer" do
    it "remembers price and quantity" do
      offer = Wsarbi::Offer.new(1.0, 2.0)
      offer.price.should eq(1.0)
      offer.quantity.should eq(2.0)
    end
  end
end
