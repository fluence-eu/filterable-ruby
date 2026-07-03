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
        Filterable::Rangeable.columns(params, scope).reduce(scope) do |sub_scope, (column, bounds)|
          max = Filterable::Rangeable.parse(bounds[:max])
          next sub_scope unless max

          sub_scope.where(scope.arel_table[column].lteq(max))
        end
      end
    end
  end
end
