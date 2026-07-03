# frozen_string_literal: true

module Filterable
  # Narrows a relation by equality from +filters[<attribute>]+. Only attributes
  # the model declared +equatable+ are honored: a scalar value compares with
  # +=+ and an array of scalars with +IN+. A blank or non-scalar value (e.g. a
  # hash injected through the query string) narrows nothing.
  module Equatable
    module_function

    # Narrows the scope to rows whose declared equatable attributes equal the
    # given values.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def call(params, scope)
      declared = scope.equatable_attribute_names
      sliced = params.slice(*declared.keys)
      sliced = sliced.to_unsafe_h if sliced.respond_to?(:to_unsafe_h)
      sliced.reduce(scope) do |sub_scope, (name, raw)|
        value = normalize(raw)
        next sub_scope if value.nil?

        sub_scope.where(declared[name] => value)
      end
    end

    # Coerce a raw filter value into a scalar or an array of scalars, or nil when
    # nothing usable remains, so a blank or malformed value narrows nothing.
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
