# frozen_string_literal: true

module Filterable
  # Namespace for the numeric bound filters and the helpers they share.
  module Rangeable
    module_function

    # Coerce a raw filter value into a number, or nil when it cannot be parsed,
    # so a malformed query param narrows nothing instead of raising. Integer
    # strings are read in base ten (never octal), anything else falls back to
    # Float.
    #
    # @api private
    # @param value [Numeric, String] the raw bound from the params.
    # @return [Numeric, nil] the parsed value, or nil when unparseable.
    def parse(value)
      case value
      when Numeric
        value
      else
        text = value.to_s
        Integer(text, 10, exception: false) || Float(text, exception: false)
      end
    end

    # Whitelist the params to the declared rangeable attributes, keeping their
    # public names. An attribute whose value is not a hash of bounds is dropped,
    # so a malformed shape narrows nothing instead of raising.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => Hash}] public name => raw bounds for that attribute.
    def bounds(params, scope)
      sliced = params.slice(*scope.rangeable_attribute_names.keys)
      sliced = sliced.to_unsafe_h if sliced.respond_to?(:to_unsafe_h)
      sliced.select { |_name, value| value.is_a?(Hash) }
    end

    # The entries of {bounds} whose given keys all parse, each public name
    # resolved to its DB column — the single place deciding whether a bound
    # applies, so a filter's +call+ and +applied+ cannot drift.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @param keys [Array<Symbol>] the bound keys the filter reads, all required.
    # @return [Array<Array(Object, Object, Hash, Hash)>] public name, DB column,
    #   raw bounds and parsed bounds for each accepted attribute.
    def accepted(params, scope, *keys)
      declared = scope.rangeable_attribute_names
      bounds(params, scope).filter_map do |name, bounds_hash|
        parsed = keys.index_with { |key| parse(bounds_hash[key]) }
        next if parsed.value?(nil)

        [name, declared[name], bounds_hash, parsed]
      end
    end
  end
end
