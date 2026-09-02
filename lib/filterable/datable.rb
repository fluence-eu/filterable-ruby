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

    BARE_DAY = /\A\d{4}-\d{2}-\d{2}\z/

    def bare_day?(value)
      case value
      when nil, DateTime, Time then false
      when Date then true
      else value.to_s.match?(BARE_DAY)
      end
    end

    def column_type(scope, target)
      klass, column =
        if target.is_a?(Hash)
          path, name = Filterable::Target.unpack(target)
          return if name.is_a?(Hash) || path.empty?

          [Filterable::Target.resolve(scope.klass, path)&.[](:klass), name]
        else
          [scope.klass, target]
        end

      klass&.type_for_attribute(column.to_s)&.type
    end

    def whole_day?(scope, target, value)
      bare_day?(value) && column_type(scope, target) == :datetime
    end

    def day_start(value)
      midnight(to_day(value))
    end

    def day_end(value)
      midnight(to_day(value) + 1)
    end

    def to_day(value)
      value.is_a?(Date) ? value.to_date : Date.parse(value.to_s)
    end

    def midnight(day)
      Time.zone ? day.in_time_zone : day.to_time
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
