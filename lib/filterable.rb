# frozen_string_literal: true

require 'time'
require 'active_record'

require_relative 'filterable/version'
require_relative 'filterable/concern'
require_relative 'filterable/attribute_normalization'
require_relative 'filterable/value_normalization'
require_relative 'filterable/target'
require_relative 'filterable/declarations_validator'
require_relative 'filterable/attachable'
require_relative 'filterable/datable'
require_relative 'filterable/datable/after'
require_relative 'filterable/datable/before'
require_relative 'filterable/datable/range'
require_relative 'filterable/datable/since'
require_relative 'filterable/equatable'
require_relative 'filterable/matchable'
require_relative 'filterable/matchable/starts_with'
require_relative 'filterable/matchable/ends_with'
require_relative 'filterable/matchable/contains'
require_relative 'filterable/rangeable'
require_relative 'filterable/rangeable/minimum'
require_relative 'filterable/rangeable/maximum'
require_relative 'filterable/scopable'
require_relative 'filterable/sortable'
require_relative 'filterable/togglable'
require_relative 'filterable/concerns/attachable'
require_relative 'filterable/concerns/datable'
require_relative 'filterable/concerns/equatable'
require_relative 'filterable/concerns/matchable'
require_relative 'filterable/concerns/rangeable'
require_relative 'filterable/concerns/scopable'
require_relative 'filterable/concerns/sortable'
require_relative 'filterable/concerns/togglable'

# Declarative, whitelisted query filtering and ordering for ActiveRecord models.
#
# In a Rails application the {Railtie} auto-includes the building blocks into
# every model, so a model only declares its columns:
#
#   class MovementDetail < ApplicationRecord
#     datable   :value_date, :booking_date
#     sortable  :value_date, :gross_amount_cents
#     equatable :reference
#     rangeable :gross_amount_cents
#     scopable  :cheaper_than
#     togglable :priced
#   end
#
#   MovementDetail.filterable(filters: { value_date: { after: '2026-02-01' }, sort: '-value_date' })
#
# Outside Rails, include the pieces manually:
#
#   include Filterable::Concern
#   include Filterable::Concerns::Datable
#   include Filterable::Concerns::Equatable
#   include Filterable::Concerns::Rangeable
#   include Filterable::Concerns::Scopable
#   include Filterable::Concerns::Sortable
#   include Filterable::Concerns::Togglable
module Filterable
  # Base error class for the gem.
  class Error < StandardError; end
end

# Loaded only inside a Rails app, where Rails::Railtie is defined. The require is
# guarded so the gem stays usable as plain ActiveRecord outside Rails.
require_relative 'filterable/railtie' if defined?(Rails::Railtie)
