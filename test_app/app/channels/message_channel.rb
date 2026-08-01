class MessageChannel < ApplicationCable::Channel
  include DexieCable

  def subscribed
    # broadcast_to("message_channel", ...) produces a key like "message:message_channel"
    stream_from self.class.broadcasting_for("message_channel")
  end
end
