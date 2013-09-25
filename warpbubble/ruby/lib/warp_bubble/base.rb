require 'time'

class WarpBubble
  class Base
    @@channel_name = 'warp_bubble'

    def initialize
      @chan_sub = Redis.new
      @chan_pub = Redis.new
    end

    def publish(payload)
      payload["now"] = Time.now.iso8601
      @chan_pub.publish(@@channel_name, payload.to_json)
    end

    def log(msg)
      short_class_name = self.class.name.split('::').drop(1).join('::')
      time = Time.now.strftime("%H:%M")
      puts "#{time} #{short_class_name}: #{msg.to_s}"
    end

    def get(key)
      JSON.parse(@chan_pub.get(key))

    end
    def set(key, value)
      value = value.to_json unless value.is_a?(String)
      @chan_pub.set(key, value)
    end
  end
end
