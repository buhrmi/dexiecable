# frozen_string_literal: true

module DexieCable
  # The single channel through which all Dexie transfer happens.
  #
  # Broadcasts are scoped to a recipient with +DexieChannel[recipient]+ or
  # +DexieChannel.broadcast_to+. String recipients are public stream names;
  # any other recipient (e.g. a record) targets a private, signed stream.
  #
  #   # private (signed)
  #   subscription.addStream(DexieChannel.stream_token_for(current_user))
  #
  #   # public (no signature, namespaced under "public:")
  #   subscription.addPublicStream("feed")
  #
  class DexieChannel < ActionCable::Channel::Base
    PUBLIC_STREAM_PREFIX = "public:"

    public :transmit

    # Open a scoped channel for broadcasting to a specific recipient.
    #
    # A String recipient is a public stream name (namespaced under
    # +public:+); any other recipient targets that recipient's own stream.
    #
    #   DexieChannel[current_user].table("notifications").add(notification)
    #   DexieChannel["feed"].table("announcements").add(announcement)
    #
    def self.[](recipient)
      target = recipient.is_a?(String) ? "#{PUBLIC_STREAM_PREFIX}#{recipient}" : recipient
      ScopedChannel.new(self, target)
    end

    # Build a query against a Dexie table, transmitted to all subscribers
    # of this channel.
    #
    #   table("messages").where(:room_id).equals(room.id).add(message)
    #
    def table(name)
      Query.new(self, name)
    end

    # Returns a signed token for the stream identifier of +target+ (private
    # record-based streams). Send it to the client, which passes it to
    # +subscription.addStream+.
    def self.stream_token_for(target)
      verifier.generate(broadcasting_for(target))
    end

    def self.verifier
      @verifier ||= Rails.application.message_verifier("dexiecable:streams")
    end

    def subscribed
      # Streams are added dynamically via +add_stream+.
    end

    def add_stream(data)
      stream = verified_stream(data["stream"])
      stream_from stream if stream
    end

    def remove_stream(data)
      stream = verified_stream(data["stream"])
      stop_stream_from stream if stream
    end

    def remove_all_streams(_data)
      stop_all_streams
    end

    def add_public_stream(data)
      name = data["stream"].to_s
      stream_from public_stream_name(name) if name.present?
    end

    def remove_public_stream(data)
      name = data["stream"].to_s
      stop_stream_from public_stream_name(name) if name.present?
    end

    private

    def public_stream_name(name)
      self.class.broadcasting_for("#{PUBLIC_STREAM_PREFIX}#{name}")
    end

    def verified_stream(token)
      return unless token.present?

      self.class.verifier.verify(token)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
  end
end
