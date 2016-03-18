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

    def remove(x_offer : Offer)
      puts "attempting removal of #{x_offer.exchange} $#{x_offer.price} in bin #{@price}/#{@offers.size}"
      @offers.reject! do |offer|
        offer.exchange == x_offer.exchange && offer.price == x_offer.price
      end
    end
  end
end
