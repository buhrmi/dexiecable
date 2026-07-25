# frozen_string_literal: true

module DexieCable
  extend ActiveSupport::Concern

  included do
    public :transmit

    # Open a scoped channel for broadcasting to a specific subject.
    #
    #   UserChannel[current_user].table("notifications").add(notification)
    #
    def self.[](subject)
      ScopedChannel.new(self, subject)
    end

    # Build a query against a Dexie table, transmitted to all subscribers
    # of this channel.
    #
    #   table("messages").where(:room_id).equals(room.id).add(message)
    #
    def table(name)
      Query.new(self, name)
    end
  end
end
