module Wsarbi
  class Market
    getter :offers

    enum BidAsk
      Bid
      Ask
    end

    def initialize(bidask : BidAsk)
      @offers = [] of Offer
      if bidask == BidAsk::Bid
        @better_proc = ->(was : Float64, is : Float64) { is <=> was }
      else
        @better_proc = ->(was : Float64, is : Float64) { was <=> is }
      end
    end

    def add(offers : Array(Offer))
      # TODO: sorted insert
      @offers += offers
      @offers.sort! { |a, b| @better_proc.call(a.price, b.price) }
    end

    def best
      @offers.first
    end

    def better_than(price : Float64)
      @offers.select { |offer| @better_proc.call(offer.price, price) == 1 }
    end
  end
end
