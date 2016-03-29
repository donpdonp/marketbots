module Wsarbi
  class Offer
    getter exchange : String, market : String, price : FauxDecimal
    # streaming updates change the quantity
    property quantity : FauxDecimal

    def initialize(@exchange : String, @market : String, price : String, quantity : String)
      @price = FauxDecimal.new(price, 8)
      @quantity = FauxDecimal.new(quantity, 8)
    end

    def value
      price.to_f * quantity.to_f
    end

    def dup_worksheet : OfferWorksheet
      OfferWorksheet.new(self)
    end

    def to_s(io)
      io << "$#{price} #{quantity}x"
    end
  end

  class OfferWorksheet
    getter offer : Offer
    property remaining : Float64

    def initialize(@offer : Offer)
      @remaining = @offer.quantity.to_f
    end

    def quantity : Float64
      @offer.quantity.to_f
    end

    def exchange : String
      @offer.exchange
    end

    def price : Float64
      @offer.price.to_f
    end
  end
end
