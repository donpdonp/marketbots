module Wsarbi
  class Orderbook
    def initialize
      puts "New Orderbook"
      @bids = [] of Offer
      @asks = [] of Offer
    end

    def add_bids(offers : Array(Offer))
    end

    def add_asks(offers : Array(Offer))
    end
  end
end
