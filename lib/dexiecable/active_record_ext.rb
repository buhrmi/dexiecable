# frozen_string_literal: true

module DexieCable
  module ActiveRecordExt
    extend ActiveSupport::Concern

    class_methods do
      # Declares that this model syncs changes to Dexie (IndexedDB) via a
      # DexieCable channel.
      #
      #   class Message < ApplicationRecord
      #     syncs_to_dexie via: -> { UserChannel[sender] }
      #     syncs_to_dexie via: -> { UserChannel[receiver] }
      #     syncs_to_dexie via: PublicChannel
      #   end
      #
      # @param via    [Proc, DexieCable, Array<DexieCable>] Proc evaluated in
      #                 record context, must return a channel (or array of
      #                 channels) that responds to +table+. Skipped if nil.
      # @param table  [String, Symbol, Proc] Override the Dexie table name
      #                (defaults to the model's table_name). A Proc is
      #                evaluated in the record's context.
      # @param only   [Array<Symbol>] Limit which lifecycle events sync.
      #                Default: [:create, :update, :destroy].
      # @param if     [Symbol, Proc] Only sync if the given method or proc
      #                returns truthy (evaluated in the record's context).
      # @param unless [Symbol, Proc] Skip sync if the given method or proc
      #                returns truthy (evaluated in the record's context).
      def syncs_to_dexie(via:, table: nil, only: nil, **options)
        events     = Array(only || %i[create update destroy])
        conditions = options.slice(:if, :unless)

        @dexie_sync_configs ||= []
        @dexie_sync_configs << { via: via, table: table, only: events, **conditions }

        if events.include?(:destroy)
          before_destroy :dexie_sync_before_destroy

          after_commit on: :destroy, **conditions do
            Array(resolve_channel(via)).each do |channel|
              next unless channel
              channel.table(resolve_table(table)).delete(dexie_destroy_id)
            end
          end
        end

        if events.include?(:create)
          after_commit on: :create, **conditions do
            Array(resolve_channel(via)).each do |channel|
              next unless channel
              channel.table(resolve_table(table)).add(as_json_for_dexie)
            end
          end
        end

        if events.include?(:update)
          after_commit on: :update, **conditions do
            Array(resolve_channel(via)).each do |channel|
              next unless channel

              changes = as_json_for_dexie.slice(*saved_changes.keys)
              channel.table(resolve_table(table)).update(id, changes)
            end
          end
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
