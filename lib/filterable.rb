# frozen_string_literal: true

require 'time'
require 'active_record'

require_relative 'filterable/version'
require_relative 'filterable/concern'
require_relative 'filterable/attribute_normalization'
require_relative 'filterable/datable'
require_relative 'filterable/datable/after'
require_relative 'filterable/datable/before'
require_relative 'filterable/datable/range'
require_relative 'filterable/datable/since'
require_relative 'filterable/equatable'
require_relative 'filterable/sortable'
require_relative 'filterable/concerns/datable'
require_relative 'filterable/concerns/equatable'
require_relative 'filterable/concerns/sortable'

# Declarative, whitelisted query filtering and ordering for ActiveRecord models.
#
# In a Rails application the {Railtie} auto-includes the building blocks into
# every model, so a model only declares its columns:
#
#   class MovementDetail < ApplicationRecord
#     datable   :value_date, :booking_date
#     sortable  :value_date, :gross_amount_cents
#     equatable :reference
#   end
#
#   MovementDetail.filterable(filters: { value_date: { after: '2026-02-01' }, sort: '-value_date' })
#
# Outside Rails, include the pieces manually:
#
#   include Filterable::Concern
#   include Filterable::Concerns::Datable
#   include Filterable::Concerns::Equatable
#   include Filterable::Concerns::Sortable
module Filterable
  # Base error class for the gem.
  class Error < StandardError; end
end

# Loaded only inside a Rails app, where Rails::Railtie is defined. The require is
# guarded so the gem stays usable as plain ActiveRecord outside Rails.
require_relative 'filterable/railtie' if defined?(Rails::Railtie)
