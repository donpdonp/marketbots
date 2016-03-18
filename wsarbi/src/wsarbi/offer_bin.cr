module Wsarbi
  class OfferBin
    getter :price, :offers

    def initialize(price : Float64, decimals : Float64) # Int32 causes problems
      @price = price.round(decimals)
      @offers = [] of Offer
    end

    def value
      @offers.sum{|offer| offer.price * offer.quantity}
    end
  end
end
