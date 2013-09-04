class WarpBubble
  class TickTock < Base
    def go
      loop do
        @chan_pub.publish(@@channel_name, '{"time":1}')
        sleep 5
      end
    end
  end
end

WarpBubble.add_service({"name" => "TickTock", "thread" => Thread.new do
  WarpBubble::TickTock.new.go
end})
