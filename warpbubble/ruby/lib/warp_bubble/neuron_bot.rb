class WarpBubble
  class NeuronBot
    def initialize(wb)
      @wb = wb
    end

    def dispatch(payload)
      if payload["type"] == 'emessage'
        if match = payload["message"].match(/^balances/)
          @wb.publish({"action" => "balance refresh", "payload" => {"exchange" => "*"}})
        elsif match = payload["message"].match(/^ready/)
          @wb.publish({"action" => "balance ready", "payload" => {}})
        elsif match = payload["message"].match(/^plan drop/)
          @wb.publish({"action" => "plan drop", "payload" => {}})
        elsif match = payload["message"].match(/^(\w+)\s+(\w+)\s+(\w+)/)
          @wb.publish({"action" => "#{match[2]} #{match[3]}", "payload" => {"exchange" => match[1]}})
        end
      end
    end
  end
end
