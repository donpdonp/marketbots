require 'httparty'
require 'redis'

class WarpBubble
  @@version = "0.01"
  def self.version; @@version; end

  class Base
    @@channel_name = 'warp_bubble'

    def initialize
      @chan_sub = Redis.new
      @chan_pub = Redis.new
    end
  end
end

Dir['lib/warp_bubble/*'].each{|filename| require filename.split('/')[-2,2].join('/')}

