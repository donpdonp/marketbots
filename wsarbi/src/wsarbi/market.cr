module Wsarbi
  class Market
    getter :offers

    enum BidAsk
      Bid
      Ask
    end

    def initialize(bidask : BidAsk)
      puts "New Market"
      @offers = [] of Offer
      if bidask == BidAsk::Bid
        @better_proc = ->(offer : Offer, price : Float64) { offer.price > price }
      else
        @better_proc = ->(offer : Offer, price : Float64) { offer.price < price }
      end
    end

    def add(offers : Array(Offer))
      # TODO: sorted insert
      @offers += offers
      @offers.sort_by! { |o| o.price }
    end

    def best
      @offers.first
    end

    def better_than(price : Float64)
      @offers.select { |offer| @better_proc.call(offer, price) }
    end
  end
end
