# frozen_string_literal: true

module Filterable
  module Rangeable
    # Keeps rows whose rangeable attribute is at most the bound (inclusive).
    # Reads +filters[<attribute>][max]+.
    module Maximum
      module_function

      # Narrows the scope to rows at or below each declared attribute's +max+ bound.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        entries = Filterable::Rangeable.accepted(params, scope, :max)
        entries.reduce(scope) do |sub_scope, (_name, column, _bounds, parsed)|
          sub_scope.where(scope.arel_table[column].lteq(parsed[:max]))
        end
      end

      # The bounds {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted +max+ bound.
      def applied(params, scope)
        entries = Filterable::Rangeable.accepted(params, scope, :max)
        entries.each_with_object({}) do |(name, _column, bounds, _parsed), report|
          report[name] = bounds.slice(:max)
        end
      end
    end
  end
end
