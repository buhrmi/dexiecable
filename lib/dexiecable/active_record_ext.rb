# frozen_string_literal: true

module DexieCable
  module ActiveRecordExt
    extend ActiveSupport::Concern

    class_methods do
      # Declares that this model syncs changes to Dexie (IndexedDB) via
      # DexieChannel.
      #
      #   class Message < ApplicationRecord
      #     syncs_to_dexie via: :sender
      #     syncs_to_dexie via: "global_feed"
      #     syncs_to_dexie via: -> { conversation.users }
      #     syncs_to_dexie
      #   end
      #
      # @param via     [Proc, Symbol, String] A Proc evaluated in record
      #                  context, a Symbol to call via +send+, or a String
      #                  naming a public stream. Must return a single
      #                  recipient or collection of recipients. Defaults to
      #                  the record itself.
      # @param table   [String, Symbol, Proc] Override the Dexie table name
      #                 (defaults to the model's table_name). A Proc is
      #                 evaluated in the record's context.
      # @param only    [Array<Symbol>] Limit which lifecycle events sync.
      #                 Default: [:create, :update, :destroy].
      # @param with [Symbol, Proc] Method name or proc to use for
      #                 serializing records (defaults to :as_json_for_dexie).
      # @param if      [Symbol, Proc] Only sync if the given method or proc
      #                 returns truthy (evaluated in the record's context).
      # @param unless  [Symbol, Proc] Skip sync if the given method or proc
      #                 returns truthy (evaluated in the record's context).
      def syncs_to_dexie(via: nil, table: nil, only: nil, with: nil, **options)
        events     = Array(only || %i[create update destroy])
        conditions = options.slice(:if, :unless)
        serializer = with || :as_json_for_dexie

        @dexie_sync_configs ||= []
        @dexie_sync_configs << { via: via, table: table, only: events, with: serializer, **conditions }

        if events.include?(:destroy)
          before_destroy :dexie_sync_before_destroy

          after_commit on: :destroy, **conditions do
            resolve_channels(via).each do |channel|
              next unless channel
              channel.table(resolve_table(table)).delete(dexie_destroy_id)
            end
          end
        end

        if events.include?(:create)
          after_commit on: :create, **conditions do
            resolve_channels(via).each do |channel|
              next unless channel
              channel.table(resolve_table(table)).add(resolve(serializer))
            end
          end
        end

        if events.include?(:update)
          after_commit on: :update, **conditions do
            resolve_channels(via).each do |channel|
              next unless channel

              changes = resolve(serializer).slice(*saved_changes.keys)
              channel.table(resolve_table(table)).update(id, changes)
            end
          end
        end
      end
    end

    private

    def resolve_channels(via = nil)
      recipients = via ? resolve(via) : self
      Array(recipients).map { |r| DexieChannel[r] }
    end

    def resolve(val)
      case val
      when Proc   then instance_exec(&val)
      when Symbol then send(val)
      else val
      end
    end

    def resolve_table(table)
      case table
      when Proc   then instance_exec(&table).to_s
      when nil    then self.class.table_name
      else table.to_s
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
