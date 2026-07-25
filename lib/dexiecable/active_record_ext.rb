# frozen_string_literal: true

module DexieCable
  class ActiveRecordExt
    # Declares that this model syncs changes to Dexie (IndexedDB) via a
    # DexieCable channel.
    #
    #   class Message < ApplicationRecord
    #     syncs_to_dexie via: -> { UserChannel[sender] }
    #     syncs_to_dexie via: -> { UserChannel[receiver] }
    #     syncs_to_dexie via: PublicChannel
    #   end
    #
    # @param via    [Proc, DexieCable] Proc evaluated in record context,
    #                 must return a channel (responds to +table+). A channel
    #                 class/instance can also be passed directly. Skipped if nil.
    # @param table  [String, Symbol] Override the Dexie table name
    #                (defaults to the model's table_name).
    # @param only   [Array<Symbol>] Limit which lifecycle events sync.
    #                Default: [:create, :update, :destroy].
    def self.syncs_to_dexie(via:, table: nil, only: nil)
      table_name = (table || self.table_name).to_s
      events     = Array(only || %i[create update destroy])

      @dexie_sync_configs ||= []
      @dexie_sync_configs << { via: via, table: table_name, only: events }

      if events.include?(:destroy)
        before_destroy :dexie_sync_before_destroy

        after_commit on: :destroy do
          channel = resolve_channel(via)
          next unless channel
          channel.table(table_name).delete(dexie_destroy_id)
        end
      end

      if events.include?(:create)
        after_commit on: :create do
          channel = resolve_channel(via)
          next unless channel
          channel.table(table_name).add(as_json_for_dexie)
        end
      end

      if events.include?(:update)
        after_commit on: :update do
          channel = resolve_channel(via)
          next unless channel
          channel.table(table_name).put(as_json_for_dexie)
        end
      end
    end

    private

    def resolve_channel(via)
      case via
      when Proc then instance_exec(&via)
      else via
      end
    end

    # Override in your model to customise the payload synced to Dexie.
    def as_json_for_dexie
      as_json
    end

    def dexie_sync_before_destroy
      @dexie_destroy_id = id
    end

    def dexie_destroy_id
      @dexie_destroy_id
    end
  end
end
