# frozen_string_literal: true

module Filterable
  # Namespace for the date filters and the helpers they share.
  module Datable
    module_function

    # Coerce a raw filter value into the bound it names: a Date when it names a
    # whole day, a Time when it names an instant, or nil when it cannot be
    # parsed, so a malformed query param narrows nothing instead of raising.
    #
    # @api private
    # @param value [Date, Time, String] the raw bound from the params.
    # @return [Date, Time, nil] the parsed bound, or nil when unparseable.
    def parse(value)
      case value
      when DateTime then value.to_time
      when Time, Date then value
      else parse_bound(value.to_s)
      end
    end

    def parse_bound(string)
      parts = Date._parse(string)
      day = Date.new(parts[:year], parts[:mon], parts[:mday])
      parts.key?(:hour) ? (Time.zone || Time).parse(string) : day
    rescue TypeError, ArgumentError
      nil
    end

    def whole_day?(bound)
      bound.instance_of?(Date)
    end

    def midnight(day)
      Time.zone ? day.in_time_zone : day.to_time
    end

    def on_or_before(field, bound)
      whole_day?(bound) ? field.lt(midnight(bound + 1)) : field.lteq(bound)
    end

    def strictly_before(field, bound)
      field.lt(whole_day?(bound) ? midnight(bound) : bound)
    end

    def on_or_after(field, bound)
      field.gteq(whole_day?(bound) ? midnight(bound) : bound)
    end

    def strictly_after(field, bound)
      whole_day?(bound) ? field.gteq(midnight(bound + 1)) : field.gt(bound)
    end

    # Whitelist the params to the declared datable attributes, keeping their
    # public names. An attribute whose value is not a hash of bounds (e.g.
    # +filters[date]=2026-01-01+ from a query string) is dropped, so a malformed
    # shape narrows nothing instead of raising.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => Hash}] public name => raw bounds for that attribute.
    def bounds(params, scope)
      sliced = params.slice(*scope.datable_attribute_names.keys)
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
      declared = scope.datable_attribute_names
      bounds(params, scope).filter_map do |name, bounds_hash|
        parsed = keys.index_with { |key| parse(bounds_hash[key]) }
        next if parsed.value?(nil)

        [name, declared[name], bounds_hash, parsed]
      end
    end
  end
end
