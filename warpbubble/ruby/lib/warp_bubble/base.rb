class WarpBubble
  class Base
    @@channel_name = 'warp_bubble'

    def initialize
      @chan_sub = Redis.new
      @chan_pub = Redis.new
    end
  end
end
