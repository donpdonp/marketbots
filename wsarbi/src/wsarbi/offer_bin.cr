module Wsarbi
  class OfferBin
    getter :price, :offers

    def initialize(price : FauxDecimal, decimals : Int32)
      @price = price
      @offers = [] of Offer
    end

    def quantity : Float64
      @offers.sum { |offer| offer.quantity.to_f }
    end

    def exchanges
      @offers.map(&.exchange).uniq
    end

    def value : Float64
      @offers.sum(&.value)
    end

    def remove(x_offer : Offer)
      old_size = @offers.size
      @offers.reject! do |offer|
        offer.exchange == x_offer.exchange && offer.price == x_offer.price
      end
      if old_size == @offers.size
        puts "removed bin #{@price} #{x_offer.exchange} $#{x_offer.price} failed. still #{old_size}"
      else
        puts "removed bin #{@price} #{x_offer.exchange} $#{x_offer.price} (was: #{old_size})"
      end
    end

    def to_s(io)
      io << "$#{price}/#{"%02d" % offers.size}ofrs"
      if offers.size > 0
        io << "/#{offers.first.price}"
      end
      io << " #{exchanges}"
    end
  end
end
