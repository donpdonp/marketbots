module Wsarbi
  class Offer
    getter :exchange, :market, :price, :quantity
    setter :quantity

    def initialize(exchange : String, market : String, price : String, quantity : String)
      @exchange = exchange
      @market = market
      @price = FauxDecimal.new(price, 8)
      @quantity = FauxDecimal.new(quantity, 8)
    end

    def value
      price.to_f * quantity.to_f
    end

    def to_s(io)
      io << "$#{price} #{quantity}x"
    end
  end
end
