class WarpBubble
  class TickTock < Base
    def go
      @chan_pub.publish(@@channel_name, '{"time":1}')

    end
  end
end
