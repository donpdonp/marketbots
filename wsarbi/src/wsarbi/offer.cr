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
  end
end
