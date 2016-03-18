module Wsarbi
  class OfferBin
    getter :price, :offers

    def initialize(offer : Offer, decimals : Float64) # Int32 causes problems
      @price = offer.price.round(decimals)
      @offers = [] of Offer
    end

    def value
      @offers.sum{|offer| offer.price * offer.quantity}
    end
  end
end
