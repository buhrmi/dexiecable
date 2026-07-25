# frozen_string_literal: true

module DexieCable
  class ScopedChannel
    def initialize(klass, subject)
      @klass   = klass
      @subject = subject
    end

    def table(name)
      Query.new(self, name)
    end

    def transmit(data)
      @klass.broadcast_to @subject, data
    end
  end
end
