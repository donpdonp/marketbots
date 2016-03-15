module Wsarbi
  class Market
    getter :offers

    def initialize
      puts "New Market"
      @offers = [] of Offer
    end

    def add(offers : Array(Offer))
      # TODO: sorted insert
      @offers += offers
      @offers.sort_by! { |o| o.price }
    end

    def best
      @offers.first
    end
  end
end
