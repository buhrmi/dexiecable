# frozen_string_literal: true

module DexieCable
  # Include this in an ActionCable channel to add Dexie broadcasting and
  # streaming:
  #
  #   class DexieChannel < ApplicationCable::Channel
  #     include DexieCable
  #
  #     # Push initial data when a private stream is added.
  #     def subscribed_to(record, params)
  #       case record
  #       when User
  #         table("notifications").bulkAdd(record.notifications.map(&:as_json_for_dexie))
  #       end
  #     end
  #   end
  #
  # The client subscribes to that channel and adds streams dynamically:
  #
  #   subscribe(db)                 # subscribes to "DexieChannel"
  #   subscription.addStream(DexieChannel.stream_token_for(current_user))
  #   subscription.addStream("feed") # plain strings are public streams
  #
  extend ActiveSupport::Concern

  PUBLIC_STREAM_PREFIX = "public:"
  STREAM_TOKEN_PURPOSE = "dexiecable:streams"

  included do
    public :transmit
  end

  class_methods do
    # Open a scoped channel for broadcasting to a specific recipient.
    #
    # A String recipient is a public stream name (namespaced under
    # +public:+); any other recipient targets that recipient's own stream.
    def [](recipient)
      target = recipient.is_a?(String) ? "#{PUBLIC_STREAM_PREFIX}#{recipient}" : recipient
      ScopedChannel.new(self, target)
    end

    # Returns a signed token for +target+ (a record). Send it to the client,
    # which passes it to +subscription.addStream+.
    #
    # Tokens never expire by default. Pass +expires_in:+ (a duration) or
    # +expires_at:+ (a time) to limit a token's lifetime.
    def stream_token_for(target, expires_at: nil, expires_in: nil)
      options = { for: STREAM_TOKEN_PURPOSE }

      if expires_at
        options[:expires_at] = expires_at
      elsif expires_in
        options[:expires_in] = expires_in
      else
        options[:expires_at] = nil # never expire
      end

      target.to_sgid_param(**options)
    end
  end

  # Build a query against a Dexie table, transmitted to all subscribers
  # of this channel.
  def table(name)
    Query.new(self, name)
  end

  def subscribed
    # Streams are added dynamically via +add_stream+.
  end

  def add_stream(data)
    token = data["stream"].to_s
    params = data.except("action", "stream").with_indifferent_access

    if signed_token?(token)
      # A token that no longer resolves (expired, revoked, deleted record) is
      # rejected instead of being treated as a public stream name.
      record = resolve_subscribe_target(token)
      return unless record

      stream_for record
      subscribed_to(record, params)
    else
      return if token.blank?

      stream_from public_stream_name(token)
      subscribed_to(token, params)
    end
  end

  def remove_stream(data)
    token = data["stream"].to_s

    if signed_token?(token)
      record = resolve_subscribe_target(token)
      return unless record

      stop_stream_from self.class.broadcasting_for(record)
    else
      stop_stream_from public_stream_name(token) if token.present?
    end
  end

  def remove_all_streams(_data)
    stop_all_streams
  end

  # Override to push initial data when a stream is added. +record+ is the
  # resolved target — a record for private streams, or the stream name for
  # public streams — and +params+ are any extra params sent from the client.
  def subscribed_to(_record, _params)
  end

  private

  # Distinguishes a signed stream token from a public stream name. A signed
  # token keeps a valid signature even after it expires, which is what lets us
  # reject expired tokens instead of falling back to a public stream.
  def signed_token?(token)
    return false if token.blank? || SignedGlobalID.verifier.nil?

    SignedGlobalID.verifier.valid_message?(token)
  end

  def public_stream_name(name)
    self.class.broadcasting_for("#{PUBLIC_STREAM_PREFIX}#{name}")
  end

  def resolve_subscribe_target(token)
    GlobalID::Locator.locate_signed(token, for: STREAM_TOKEN_PURPOSE)
  rescue ActiveRecord::RecordNotFound, NameError
    nil
  end
end
