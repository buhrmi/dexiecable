# frozen_string_literal: true

module DexieCable
  class ScopedChannel
    def initialize(klass, recipient)
      @klass     = klass
      @recipient = recipient
    end

    def table(name)
      Query.new(self, name)
    end

    def transmit(data)
      @klass.broadcast_to @recipient, data
    end
  end
end
