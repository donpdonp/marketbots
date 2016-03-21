module Wsarbi
  class Market
    getter :bins

    enum BidAsk
      Bid
      Ask
    end

    def initialize(bidask : BidAsk, precision : Float64)
      @precision = precision
      @decimals = Math.log10(1/precision)
      @bins = [] of OfferBin
      if bidask == BidAsk::Bid
        @better_proc = ->(was : Float64, is : Float64) { is <=> was }
      else
        @better_proc = ->(was : Float64, is : Float64) { was <=> is }
      end
    end

    def add(offer : Offer)
      bin = find_or_create_closest_bin(offer)
      if offer.quantity == 0
        puts "bin #{bin.price}/#{bin.offers.size} removing offer #{offer.price}"
        bin.remove(offer)
        if bin.offers.size == 0
          puts "bin #{bin.price} empty. removing"
          @bins.delete(bin)
        end
      else
        match = bin.offers.find do |boffer|
          boffer.exchange == offer.exchange &&
            boffer.price == offer.price
        end
        if match
          match.quantity = offer.quantity
          puts "bin #{bin.price}/#{bin.offers.size} updated offer #{offer.price} to #{offer.quantity}"
        else
          bin.offers << offer
          puts "bin #{bin.price}/#{bin.offers.size} added offer #{offer.price}"
        end
      end
    end

    def best
      @bins.first
    end

    def better_than(price : Float64)
      @bins.select { |bin| @better_proc.call(bin.price, price) == -1 }
    end

    def find_or_create_closest_bin(offer : Offer)
      bin_price = bin_price_for(offer.price)
      close = @bins.find do |bin|
        bin.price == bin_price
      end
      unless close
        close = OfferBin.new(bin_price, @decimals)
        # TODO: sorted insert
        @bins << close
        @bins.sort! { |a, b| @better_proc.call(a.price, b.price) }
      end
      close
    end

    def bin_price_for(price : Float64)
      shift = 10**@decimals
      (price*shift).floor/shift
    end

    def value : Float64
      @bins.sum { |ob| ob.value }
    end

    def summary
      if bins.size > 0
        "$#{"%0.4f" % bins.first.price}/#{"%2d" % bins.first.offers.size}/#{bins.first.offers.first.price}" + " - " +
          "$#{"%0.4f" % bins.last.price}/#{"%2d" % bins.last.offers.size} " + "value #{value}/#{bins.size}bins"
      else
        "empty"
      end
    end

    def clear(exchange : String) : Int32
      count = 0
      @bins.select! do |bin|
        old_size = bin.offers.size
        bin.offers.reject! do |offer|
          offer.exchange == exchange
        end
        count += old_size - bin.offers.size
        bin.offers.size > 0
      end
      count
    end
  end
end
