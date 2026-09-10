require "test_helper"

# Test model: `via:` is a Symbol that returns an array of recipients.
class ArrayViaMessage < ApplicationRecord
  self.table_name = "messages"

  syncs_to_dexie via: :recipients, only: [:create]

  attr_accessor :recipients
end

class RecordingDexieChannel < DexieChannel
  attr_reader :received_target, :received_params

  def subscribed_to(target, params)
    @received_target = target
    @received_params = params
  end
end

class DexieChannelTest < ActionCable::Channel::TestCase
  tests RecordingDexieChannel

  test "subscribed_to receives the resolved record for private streams" do
    message = Message.create!(body: "hello")

    token = RecordingDexieChannel.stream_token_for(message)

    subscribe
    perform :add_stream, stream: token, last_seq_id: 100

    assert_equal message, subscription.received_target
    assert_equal 100, subscription.received_params["last_seq_id"]
  end

  test "stream tokens with an expiry in the past fall back to a public stream" do
    message = Message.create!(body: "hello")
    token = RecordingDexieChannel.stream_token_for(message, expires_at: 1.second.ago)

    subscribe
    perform :add_stream, stream: token

    assert_equal token, subscription.received_target
  end

  test "subscribed_to receives the stream name for public streams" do
    subscribe
    perform :add_stream, stream: "feed", last_seq_id: 200

    assert_equal "feed", subscription.received_target
    assert_equal 200, subscription.received_params["last_seq_id"]
  end

  test "syncs_to_dexie via: :recipients broadcasts to each recipient's stream" do
    recipient_a = Message.create!(body: "recipient a")
    recipient_b = Message.create!(body: "recipient b")

    record = ArrayViaMessage.new(body: "hello", recipients: [recipient_a, recipient_b])

    stream_a = DexieChannel.broadcasting_for(recipient_a)
    stream_b = DexieChannel.broadcasting_for(recipient_b)

    record.save!

    assert_broadcasts(stream_a, 1)
    assert_broadcasts(stream_b, 1)

    payload = ActiveSupport::JSON.decode(broadcasts(stream_a).first)
    assert_equal "messages", payload["table"]
    assert_equal "add", payload["ops"].first["method"]
  end
end
