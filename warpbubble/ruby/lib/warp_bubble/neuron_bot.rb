class WarpBubble
  class NeuronBot
    def initialize(wb)
      @wb = wb
    end

    def dispatch(payload)
      if payload["type"] == 'emessage'
        if payload["message"].match(/^balance/)
          @wb.publish({"action" => "balance refresh", "payload" => {"exchange" => "*"}})
        elsif payload["message"].match(/^ready/)
          @wb.publish({"action" => "balance ready", "payload" => {}})
        end
      end
    end
  end
end
