module Wsarbi
  class Offer
    getter :exchange, :market, :price, :quantity

    def initialize(exchange : String, market : String, price : Float64, quantity : Float64)
      @exchange = exchange
      @market = market
      @price = price
      @quantity = quantity
    end
  end
end
