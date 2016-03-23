module Wsarbi
  class FauxDecimal
    getter :decimal

    def initialize(decimal : String, decimals : Int32)
      @decimal = decimal
      resize!(decimals)
    end

    def to_s(io)
      io << @decimal
    end

    def to_f
      @decimal.to_f
    end

    def ==(other : FauxDecimal)
      @decimal == other.decimal
    end

    def resize!(decimals : Int32)
      decimal_size = @decimal.size
      point_position = @decimal.index('.')
      if point_position
        last_digit_position = decimal_size - 1
      else
        point_position = last_digit_position = decimal_size
      end
      actual_decimals = last_digit_position - point_position
      if actual_decimals < decimals
        new_decimal = @decimal
        if actual_decimals == 0
          new_decimal += "." # add point
        end
        new_decimal += "0" * (decimals - actual_decimals) # pad 0s
      else
        if decimals == 0
          new_decimal = @decimal[0, point_position] # remove point
        else
          new_decimal = @decimal[0, point_position + decimals + 1]
        end
      end
      @decimal = new_decimal
    end
  end
end
