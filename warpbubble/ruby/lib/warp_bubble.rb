require 'httparty'
require 'redis'

Dir['warp_bubble/*'].each{|filename| require filename}

class WarpBubble
  @@version = "0.01"

  def self.version; @@version; end

  def initialize
    puts ""
  end
end