class WarpBubble
  class Base
    @@channel_name = 'warp_bubble'

    def initialize
      @chan_sub = Redis.new
      @chan_pub = Redis.new
    end

    def log(msg)
      puts self.class.name+": "+msg
    end

    def get(key)
      JSON.parse(@chan_pub.get(key))
    end
  end
end
