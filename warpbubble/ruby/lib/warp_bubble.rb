require 'httparty'
require 'redis'

require 'warp_bubble/base'

class WarpBubble
  @@version = "0.01"
  def self.version; @@version; end

  @@services = []
  def self.services; @@services; end

  def self.add_service(descriptor)
    @@services.push(descriptor)
  end

  @@redis = Redis.new

  def mainloop
    puts "Services: #{WarpBubble.services.map{|s| s["name"]}.inspect}"
    puts "Issuing setup"
    # fix
    @@redis.publish('warp_bubble', '{"action":"warp_bubble setup"}')

    WarpBubble.services.map{|t| t["thread"].join}
  end
end

Dir['lib/warp_bubble/bubbles/*'].each{|filename| require filename.split('/')[-3,3].join('/')}
