class Message < ApplicationRecord
  streams_via MessageChannel, to: "message_channel"
  streams_via MessageChannel, to: "message_channel",
              with: :custom_payload, table: "custom_messages"
  streams_via MessageChannel, to: "message_channel",
              with: -> { { id: id, body: "#{body} [proc]" } }, table: "proc_messages"

  def custom_payload
    { id: id, body: "#{body} [symbol]" }
  end
end
