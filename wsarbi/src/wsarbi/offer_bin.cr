module Wsarbi
  class OfferBin
    getter :price, :offers

    def initialize(price : FauxDecimal, decimals : Int32)
      @price = price
      @offers = [] of Offer
    end

    def quantity
      @offers.sum { |offer| offer.quantity }
    end

    def exchanges
      @offers.map(&.exchange).uniq
    end

    def value
      @offers.sum { |offer| offer.price * offer.quantity }
    end

    def remove(x_offer : Offer)
      old_size = @offers.size
      @offers.reject! do |offer|
        offer.exchange == x_offer.exchange && offer.price == x_offer.price
      end
      if old_size == @offers.size
        puts "removed bin #{@price} #{x_offer.exchange} $#{x_offer.price} failed. still #{old_size}"
        @offers.each do |offer|
          puts "  bin #{@price} offer #{offer.exchange} #{offer.price} x#{offer.quantity}"
        end
      else
        puts "removed bin #{@price} #{x_offer.exchange} $#{x_offer.price} (was: #{old_size})"
      end
    end
  end
end
