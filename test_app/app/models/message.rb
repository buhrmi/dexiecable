class Message < ApplicationRecord
  syncs_to_dexie via: MessageChannel, to: "message_channel"
end
