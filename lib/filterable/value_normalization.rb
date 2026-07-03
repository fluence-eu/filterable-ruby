# frozen_string_literal: true

module Filterable
  # Shared by the filters that hand a params value to the query: coerce a raw
  # value into a scalar or an array of scalars, or nil when nothing usable
  # remains, so a blank or malformed value narrows nothing.
  module ValueNormalization
    module_function

    # Normalizes a single raw params value.
    #
    # @api private
    # @param value [Object] the raw value from the params.
    # @return [String, Numeric, true, false, Array, nil] the usable value, or nil.
    def normalize(value)
      case value
      when Array
        scalars = value.filter_map { |element| normalize(element) unless element.is_a?(Array) }
        scalars.empty? ? nil : scalars
      when String
        value.presence
      when Numeric, true, false
        value
      end
    end
  end
end
