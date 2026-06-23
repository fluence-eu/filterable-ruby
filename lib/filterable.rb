# frozen_string_literal: true

require 'time'
require 'active_record'
require 'zeitwerk'

require_relative 'filterable/version'

loader = Zeitwerk::Loader.for_gem
loader.setup

# Declarative, whitelisted query filtering and ordering for ActiveRecord models.
#
# Include the building blocks on a model, declare the columns you want to expose,
# and fold the registered filters over the relation from nested request params:
#
#   class MovementDetail < ApplicationRecord
#     include Filterable::Concern
#     include Filterable::Concerns::Datable
#     include Filterable::Concerns::Sortable
#
#     datable  :value_date, :booking_date
#     sortable :value_date, :gross_amount_cents
#   end
#
#   MovementDetail.filterable(filters: { value_date: { after: "2026-02-01" }, sort: "-value_date" })
module Filterable
  class Error < StandardError; end

  # Eager-load every file so loading errors surface at boot instead of on first use.
  def self.eager_load!
    @loader&.eager_load
  end
end

# `loader` is a local of this file's top-level scope, invisible inside the reopened
# module body — stash it on the module from out here so eager_load! can reach it.
Filterable.instance_variable_set(:@loader, loader)
