module Wsarbi
  class Offer
    getter :price, :quantity

    def initialize(price : Float64, quantity : Float64)
      @price = price
      @quantity = quantity
    end
  end
end
