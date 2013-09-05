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

  @@channel_name = 'warp_bubble'
  @@redis = Redis.new

  def initialize
    Thread.new do
      listen
    end
  end

  def listen
    Redis.new.subscribe(@@channel_name) do |on|
      on.subscribe do |channel, count|
      end

      on.message do |channel, json|
        message = JSON.parse(json)
        puts "WarpBubble: "+message.inspect
      end
    end
  end

  def mainloop
    puts "Services: #{WarpBubble.services.map{|s| s["name"]}.inspect}"
    puts "Issuing setup"
    publish({"action" => "warp_bubble setup"})

    WarpBubble.services.map{|t| t["thread"].join}
  end

  def publish(msg)
    @@redis.publish(@@channel_name, msg.to_json)
  end
end

Dir['lib/warp_bubble/bubbles/*'].each{|filename| require filename.split('/')[-3,3].join('/')}
