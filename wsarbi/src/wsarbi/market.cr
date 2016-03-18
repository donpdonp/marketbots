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

      bin.offers << offer
      # TODO: sorted insert
      @bins.sort! { |a, b| @better_proc.call(a.price, b.price) }
    end

    def best
      @bins.first
    end

    def better_than(price : Float64)
      @bins.select { |bin| @better_proc.call(bin.price, price) == -1 }
    end

    def find_or_create_closest_bin(offer : Offer)
      close = @bins.find do |bin_a|
        offer.price >= bin_a.price && offer.price < (bin_a.price+@precision)
      end
      unless close
        close = OfferBin.new(offer.price, @decimals)
        @bins << close
      end
      close
    end

    def value : Float64
      @bins.sum{|ob| ob.value}
    end

    def summary
      if bins.size > 0
        "$#{bins.first.price}/#{bins.first.offers.size} - $#{bins.last.price}/#{bins.last.offers.size} value #{value}/#{bins.size}"
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
