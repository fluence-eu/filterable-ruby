# frozen_string_literal: true

require 'simplecov'
if ENV['SKIP_COVERAGE']
  SimpleCov.at_exit {} # no-op: skip reporting entirely
else
  require 'undercover/simplecov_formatter'

  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/lib/filterable/version.rb'
    minimum_coverage 95
    minimum_coverage_by_file 70
    formatter SimpleCov::Formatter::MultiFormatter.new(
      [
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::Undercover
      ]
    )
  end
end

# Load Rails (defines Rails::Railtie) *before* requiring the gem so its guarded
# `require_relative 'filterable/railtie'` fires — the suite exercises the real
# Rails integration path, not just the manual includes.
require 'rails'
require 'filterable'
require 'action_controller'

# An in-memory database so the filters run against real SQL, with no server to
# set up. Referencing ActiveRecord::Base here also loads it, firing the
# :active_record load hook.
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

# Run the Railtie's initializer exactly as Rails would at boot: it registers
# `on_load(:active_record)`, and since ActiveRecord::Base is already loaded the
# engine is mixed into it immediately. From here every model has `filterable`
# and the datable/sortable DSL with no explicit `include`.
Filterable::Railtie.instance.run_initializers

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :movement_details, force: true do |t|
    t.date :value_date
    t.date :booking_date
    t.integer :gross_amount_cents
    t.string :reference
  end
end

# Note the absence of any `include`: the Railtie auto-included the engine into
# ActiveRecord::Base, so the model only declares its whitelisted columns.
class MovementDetail < ActiveRecord::Base
  datable :value_date, :booking_date
  sortable :value_date, :gross_amount_cents
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Each example runs inside a rolled-back transaction, so the database starts empty.
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
