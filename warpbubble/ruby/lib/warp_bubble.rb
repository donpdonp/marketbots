require 'httparty'
require 'redis'

class WarpBubble
  @@version = "0.01"
  def self.version; @@version; end

  @@services = []
  def self.services; @@services; end

  def self.add_service(descriptor)
    @@services.push(descriptor)
  end

  class Base
    @@channel_name = 'warp_bubble'

    def initialize
      @chan_sub = Redis.new
      @chan_pub = Redis.new
    end
  end
end

Dir['lib/warp_bubble/*'].each{|filename| require filename.split('/')[-2,2].join('/')}

puts "WarpBubble v#{WarpBubble.version}"
puts "Services: #{WarpBubble.services.map{|s| s["name"]}.inspect}"
puts "Issuing setup"
# fix
Redis.new.publish('warp_bubble', '{"action":"setup"}')

WarpBubble.services.map{|t| t["thread"].join}
