require 'time'

class WarpBubble
  class Base
    @@channel_name = 'warp_bubble'

    def initialize
      @chan_sub = Redis.new
      @chan_pub = Redis.new
      @irc_channel = @chan_pub.get('warpbubble:ircchannel')
      log "IRC #{@irc_channel}"
    end

    def publish(payload)
      payload["now"] = Time.now.iso8601
      @chan_pub.publish(@@channel_name, payload.to_json)
    end

    def log(msg)
      short_class_name = self.class.name.split('::').drop(1).join('::')
      time = Time.now.strftime("%H:%M")
      puts "#{time} #{short_class_name}: #{msg.to_s}"
      irc_say "#{short_class_name}: #{msg.to_s}"
    end

    def get(key)
      JSON.parse(@chan_pub.get(key))
    end

    def set(key, value)
      value = value.to_json unless value.is_a?(String)
      @chan_pub.set(key, value)
    end

    def del(key)
      @chan_pub.del(key)
    end

    def irc_say(msg)
      if @irc_channel
        @chan_pub.publish('say', {"command"=>"say","target"=>@irc_channel,"message"=>msg}.to_json)
      end
    end
  end
end
