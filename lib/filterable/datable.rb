# frozen_string_literal: true

module Filterable
  # Namespace for the date filters and the helpers they share.
  module Datable
    module_function

    # Coerce a raw filter value into a Date/Time, or nil when it cannot be parsed,
    # so a malformed query param narrows nothing instead of raising.
    #
    # @api private
    # @param value [Date, Time, String] the raw bound from the params.
    # @return [Date, Time, nil] the parsed value, or nil when unparseable.
    def parse(value)
      case value
      when Date, Time
        value
      else
        begin
          Time.parse(value.to_s)
        rescue ArgumentError
          nil
        end
      end
    end

    # Whitelist the params to the declared datable attributes and resolve each one
    # to its DB column, so a filter only ever touches columns the model opted in.
    # An attribute whose value is not a hash of bounds (e.g. +filters[date]=2026-01-01+
    # from a query string) is dropped, so a malformed shape narrows nothing
    # instead of raising.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => Hash}] db_column => raw bounds for that attribute.
    def columns(params, scope)
      declared = scope.datable_attribute_names
      sliced = params.slice(*declared.keys)
      sliced = sliced.to_unsafe_h if sliced.respond_to?(:to_unsafe_h)
      sliced.select { |_name, bounds| bounds.is_a?(Hash) }.transform_keys { |name| declared[name] }
    end
  end
end
