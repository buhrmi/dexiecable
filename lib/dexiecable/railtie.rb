# frozen_string_literal: true

module DexieCable
  class Railtie < Rails::Railtie
    initializer "dexiecable.active_record" do
      ActiveSupport.on_load(:active_record) do
        include DexieCable::ActiveRecordExt
      end
    end
  end
end
