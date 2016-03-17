module Wsarbi
  class Market
    getter :offers

    enum BidAsk
      Bid
      Ask
    end

    def initialize(bidask : BidAsk, precision : Float64)
      @precision = precision
      @decimals = Math.log10(1/precision)
      @offers = [] of OfferBin
      if bidask == BidAsk::Bid
        @better_proc = ->(was : Float64, is : Float64) { is <=> was }
      else
        @better_proc = ->(was : Float64, is : Float64) { was <=> is }
      end
    end

    def add(offer : Offer)
      bin = closest_bin(offer)
      @offers << bin
      # TODO: sorted insert
      @offers.sort! { |a, b| @better_proc.call(a.bin, b.bin) }
    end

    def best
      @offers.first
    end

    def better_than(price : Float64)
      @offers.select { |offer| @better_proc.call(offer.bin, price) == -1 }
    end

    def closest_bin(offer : Offer)
      close = @offers.find do |offer_a|
        offer.price >= offer_a.bin && offer.price < (offer_a.bin+@precision)
      end
      close || OfferBin.new(offer, @decimals)
    end
  end
end
