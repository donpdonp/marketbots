require "../spec_helper"

module Wsarbi
  describe "FauxDecimal" do
    describe "#fixed_length" do
      it "expands and contracts decimals" do
        FauxDecimal.new("1", 0).to_s.should eq("1")
        FauxDecimal.new("1", 1).to_s.should eq("1.0")
        FauxDecimal.new("1.23", 0).to_s.should eq("1")
        FauxDecimal.new("1.23", 1).to_s.should eq("1.2")
        FauxDecimal.new("1.23", 2).to_s.should eq("1.23")
        FauxDecimal.new("1.23", 3).to_s.should eq("1.230")
      end
    end
  end
end
