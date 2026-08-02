class Message < ApplicationRecord
  syncs_to_dexie via: MessageChannel, to: "message_channel"
  syncs_to_dexie via: MessageChannel, to: "message_channel",
                 with: :custom_payload, table: "custom_messages"
  syncs_to_dexie via: MessageChannel, to: "message_channel",
                 with: -> { { id: id, body: "#{body} [proc]" } }, table: "proc_messages"

  def custom_payload
    { id: id, body: "#{body} [symbol]" }
  end
end
