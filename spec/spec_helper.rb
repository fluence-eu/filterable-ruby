# frozen_string_literal: true

require 'simplecov'
if ENV['SKIP_COVERAGE']
  SimpleCov.at_exit {} # no-op: skip reporting entirely
else
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/lib/filterable/version.rb'
    minimum_coverage 90
  end
end

require 'filterable'
require 'action_controller'

# Surface any autoloading mistake at boot rather than on first use.
Filterable.eager_load!

# A throwaway in-memory database so the filters run against real SQL, with no
# server to set up. The schema mirrors the columns the test model exposes.
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :movement_details, force: true do |t|
    t.date :value_date
    t.date :booking_date
    t.integer :gross_amount_cents
    t.string :reference
  end
end

# The model under test: declares value_date/booking_date as datable and
# value_date/gross_amount_cents as sortable, just like the host application.
class MovementDetail < ActiveRecord::Base
  include Filterable::Concern
  include Filterable::Concerns::Datable
  include Filterable::Concerns::Sortable

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
