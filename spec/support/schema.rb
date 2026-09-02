# frozen_string_literal: true

# The business tables the suite runs against. Extracted so the ActiveStorage
# integration spec can rebuild them after its Rails boot replaces the
# in-memory database connection.
module FilterableSchema
  module_function

  # (Re)creates every business table on the current connection.
  #
  # @return [void]
  def define
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table :banks, force: true do |t|
        t.string :name
      end

      create_table :accounts, force: true do |t|
        t.string :name
        t.integer :balance_cents
        t.date :opened_on
        t.integer :bank_id
      end

      create_table :movement_details, force: true do |t|
        t.date :value_date
        t.date :booking_date
        t.datetime :quoted_at
        t.integer :gross_amount_cents
        t.string :reference
        t.integer :account_id
        t.string :attachable_type
        t.integer :attachable_id
        t.string :source_type
        t.integer :source_id
      end
    end
  end
end
