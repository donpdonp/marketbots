module Wsarbi
  class Market
    getter :bins

    enum BidAsk
      Bid
      Ask
    end

    def initialize(bidask : BidAsk, precision : Float64)
      @precision = precision
      @decimals = Math.log10(1/precision).to_i32
      @bins = [] of OfferBin
      @side = bidask
      if bidask == BidAsk::Bid
        @better_proc = ->(was : Float64, is : Float64) { is <=> was }
      else
        @better_proc = ->(was : Float64, is : Float64) { was <=> is }
      end
    end

    def add(offer_bins : Array(OfferBin))
      offer_bins.each do |ob|
        ob.offers.each { |o| add(o) }
      end
    end

    def add(offer : Offer)
      bin = find_or_create_closest_bin(offer.price)
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
          puts "bin #{bin.price.to_s}/#{bin.offers.size} updated offer #{offer.price.to_s} to #{offer.quantity}"
        else
          bin.offers << offer
          bin.offers.sort! { |a, b| @better_proc.call(a.price.to_f, b.price.to_f) }
        end
      end
    end

    def best
      @bins.first
    end

    def size
      @bins.size
    end

    def better_than(price : FauxDecimal)
      @bins.select { |bin| @better_proc.call(bin.price.to_f, price.to_f) == -1 }
    end

    def find_or_create_closest_bin(price : FauxDecimal)
      bin_price = bin_price_for(price)
      close = @bins.find do |bin|
        bin.price == bin_price
      end
      unless close
        close = OfferBin.new(bin_price, @decimals)
        # TODO: sorted insert
        @bins << close
        sort!
      end
      close
    end

    private def sort!
      @bins.sort! { |a, b| @better_proc.call(a.price.to_f, b.price.to_f) }
    end

    def bin_price_for(price : FauxDecimal)
      FauxDecimal.new(price.to_s, @decimals)
    end

    def value : Float64
      @bins.sum { |ob| ob.value }
    end

    def quantity : Float64
      @bins.sum { |ob| ob.quantity }
    end

    def summary
      if bins.size > 0
        "$#{bins.first.price}/#{"%02d" % bins.first.offers.size}/#{bins.first.offers.first.price} #{bins.first.exchanges}" + " - " +
          "$#{bins.last.price}/#{"%02d" % bins.last.offers.size} " + "value #{"%0.1f" % value}btc/#{bins.size}bins"
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
