# frozen_string_literal: true

require_relative "dexiecable/version"
require_relative "dexiecable/concern"
require_relative "dexiecable/scoped_channel"
require_relative "dexiecable/query"
require_relative "dexiecable/active_record_ext"
require_relative "dexiecable/railtie" if defined?(Rails::Railtie)

module DexieCable
  class Error < StandardError; end
end
