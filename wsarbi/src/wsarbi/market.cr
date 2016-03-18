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
      bin = closest_bin(offer)
      bin.offers << offer
      @bins << bin
      # TODO: sorted insert
      @bins.sort! { |a, b| @better_proc.call(a.price, b.price) }
    end

    def best
      @bins.first
    end

    def better_than(price : Float64)
      @bins.select { |bin| @better_proc.call(bin.price, price) == -1 }
    end

    def closest_bin(offer : Offer)
      close = @bins.find do |bin_a|
        offer.price >= bin_a.price && offer.price < (bin_a.price+@precision)
      end
      close || OfferBin.new(offer, @decimals)
    end
  end
end
