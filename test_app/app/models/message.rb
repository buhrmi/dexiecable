class Message < ApplicationRecord
  streams_to_dexie via: MessageChannel, to: "message_channel"
  streams_to_dexie via: MessageChannel, to: "message_channel",
                 with: :custom_payload, table: "custom_messages"
  streams_to_dexie via: MessageChannel, to: "message_channel",
                 with: -> { { id: id, body: "#{body} [proc]" } }, table: "proc_messages"

  def custom_payload
    { id: id, body: "#{body} [symbol]" }
  end
end
