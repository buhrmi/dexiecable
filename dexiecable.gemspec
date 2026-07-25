# frozen_string_literal: true

require_relative "lib/dexiecable/version"

Gem::Specification.new do |spec|
  spec.name          = "dexiecable"
  spec.version       = DexieCable::VERSION
  spec.authors       = ["Keoscout"]
  spec.summary       = "Run Dexie.js IndexedDB operations from your Rails ActionCable channels."
  spec.description   = "DexieCable augments ActionCable channels with a query DSL that mirrors " \
                       "the Dexie.js API, letting you push database mutations from the server to " \
                       "the client in real time. Includes an ActiveRecord macro (syncs_to_dexie) " \
                       "for automatic change syncing."
  spec.homepage      = "https://github.com/keoscout/dexiecable"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]

  spec.add_dependency "actioncable", ">= 7.0"
  spec.add_dependency "activerecord", ">= 7.0"
end
