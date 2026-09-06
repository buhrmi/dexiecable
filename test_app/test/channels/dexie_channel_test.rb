require "test_helper"

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

  test "stream tokens with an expiry in the past do not resolve" do
    message = Message.create!(body: "hello")
    token = RecordingDexieChannel.stream_token_for(message, expires_at: 1.second.ago)

    subscribe
    perform :add_stream, stream: token

    assert_nil subscription.received_target
  end

  test "subscribed_to receives the stream name for public streams" do
    subscribe
    perform :add_public_stream, stream: "feed", last_seq_id: 200

    assert_equal "feed", subscription.received_target
    assert_equal 200, subscription.received_params["last_seq_id"]
  end
end
