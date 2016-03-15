require "../spec_helper"

module Wsarbi
  describe "Orderbook" do
    subject = Orderbook.new

    it "remembers price and quantity" do
      subject.profitables.size.should eq(0)
    end
  end
end
