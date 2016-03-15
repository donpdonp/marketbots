module Wsarbi
  class Orderbook
    getter :bids, :asks

    def initialize
      puts "New Orderbook"
      @bids = Market.new
      @asks = Market.new
    end

    def profitables
      ask_price = @asks.best.price
      bid_price = @bids.best.price
      if ask_price < bid_price
        puts "Winner"
      end
    end
  end
end
