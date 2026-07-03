# frozen_string_literal: true

module Filterable
  module Datable
    # Keeps rows whose datable attribute falls within an inclusive range.
    # Reads +filters[<attribute>][from]+ and +filters[<attribute>][to]+, applied
    # only when both bounds are present and parseable.
    module Range
      module_function

      # Narrows the scope to rows within each declared attribute's inclusive +from+/+to+ range.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        Filterable::Datable.columns(params, scope).reduce(scope) do |sub_scope, (column, bounds)|
          from = Filterable::Datable.parse(bounds[:from])
          to = Filterable::Datable.parse(bounds[:to])
          next sub_scope unless from && to

          field = scope.arel_table[column]
          sub_scope.where(field.gteq(from)).where(field.lteq(to))
        end
      end

      # The bounds {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted +from+/+to+ bounds.
      def applied(params, scope)
        Filterable::Datable.bounds(params, scope).each_with_object({}) do |(name, bounds), report|
          next unless Filterable::Datable.parse(bounds[:from]) && Filterable::Datable.parse(bounds[:to])

          report[name] = { from: bounds[:from], to: bounds[:to] }
        end
      end
    end
  end
end
