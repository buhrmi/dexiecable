# frozen_string_literal: true

module DexieCable
  # Builds a chain of Dexie.js operations and transmits them as a single
  # payload once a write operation is reached.
  #
  #   DexieCable::Query.new(channel, "messages")
  #     .where(:room_id).equals(5)
  #     .add(text: "hello")
  #
  class Query
    WRITE_OPS = %i[
      add bulkAdd put bulkPut bulkDelete
      upsert update delete modify clear
    ].freeze

    attr_accessor :query

    def initialize(transmitter, name)
      @transmitter = transmitter
      @query = { table: name, ops: [] }
    end

    def method_missing(method, *params)
      @query[:ops] << { method: method, params: params }
      if WRITE_OPS.include?(method)
        @transmitter.transmit(query)
      else
        self
      end
    end

    def respond_to_missing?(method, *)
      true
    end
  end
end
