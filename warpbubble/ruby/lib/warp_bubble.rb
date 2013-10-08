require 'httparty'
require 'redis'

require 'warp_bubble/base'
require 'warp_bubble/neuron_bot'
require 'warp_bubble/bubbles/exchanges/base'

class WarpBubble
  @@version = "0.0.2"
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
      warp_bubble_listen
    end

    if irc_channel = @@redis.get('warpbubble:ircchannel')
      puts "Warpbubble: IRC #{irc_channel}"
      @neuronbot = NeuronBot.new(self)
      Thread.new do
        neuronbot_listen
      end
    end
  end

  def warp_bubble_listen
    Redis.new.subscribe(@@channel_name) do |on|
      on.subscribe do |channel, count|
      end

      on.message do |channel, json|
        message = JSON.parse(json)
      end
    end
  end

  def neuronbot_listen
    Redis.new.subscribe('lines') do |on|
      on.message do |channel, json|
        message = JSON.parse(json)
        @neuronbot.dispatch(message)
      end
    end
  end

  def mainloop
    puts "WarpBubble: Starting services: #{WarpBubble.services.map{|s| s["name"]}.inspect}"
    puts "WarpBubble: Issuing setup"
    publish({"action" => "warp_bubble setup"})

    until WarpBubble.services.any? {|svc| svc["thread"].status.nil?}
      WarpBubble.services.each{|svc| svc["thread"].join(0.5)}
    end
  end

  def publish(msg)
    @@redis.publish(@@channel_name, msg.to_json)
  end
end

Dir['lib/warp_bubble/bubbles/**/*rb'].map{|filename| filename.split('/').drop(1).join('/')}.each{|f| require f}

