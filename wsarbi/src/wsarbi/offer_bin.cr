module Wsarbi
  class OfferBin
    getter :bin, :offer

    def initialize(offer : Offer, decimals : Float64) # Int32 causes problems
      @bin = offer.price.round(decimals)
      @offer = offer
    end
  end
end
