# frozen_string_literal: true

module Filterable
  module Rangeable
    # Keeps rows whose rangeable attribute is at least the bound (inclusive).
    # Reads +filters[<attribute>][min]+.
    module Minimum
      module_function

      # Narrows the scope to rows at or above each declared attribute's +min+ bound.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        Filterable::Rangeable.columns(params, scope).reduce(scope) do |sub_scope, (column, bounds)|
          min = Filterable::Rangeable.parse(bounds[:min])
          next sub_scope unless min

          sub_scope.where(scope.arel_table[column].gteq(min))
        end
      end

      # The bounds {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted +min+ bound.
      def applied(params, scope)
        Filterable::Rangeable.bounds(params, scope).each_with_object({}) do |(name, bounds), report|
          report[name] = { min: bounds[:min] } if Filterable::Rangeable.parse(bounds[:min])
        end
      end
    end
  end
end
