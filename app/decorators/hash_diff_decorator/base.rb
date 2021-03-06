module HashDiffDecorator
  class Base < BaseDecorator
    alias_method :change, :__getobj__

    def change_type
      change[0]
    end

    def field
      change[1]
    end

    def to_html
      raise "Needs to be implemented by the subclass."
    end

    protected

    def diff_val(val)
      if val.nil?
        "[nil]"
      elsif val.is_a?(Numeric)
        diff_numeric(val)
      elsif val.try(:empty?)
        "[empty]"
      else
        val.inspect
      end
    end

    def diff_numeric(val)
      if val.is_a?(Fixnum)
        val.to_s
      elsif val.is_a?(Numeric)
        format("%.2f", val)
      end
    end
  end
end
