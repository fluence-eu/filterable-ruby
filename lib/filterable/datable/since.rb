# frozen_string_literal: true

module Filterable
  module Datable
    # Keeps rows whose datable attribute is on or before the bound (inclusive).
    # Reads +filters[<attribute>][since]+.
    module Since
      module_function

      # Narrows the scope to rows on or before each declared attribute's +since+ bound.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        Filterable::Datable.columns(params, scope).reduce(scope) do |sub_scope, (column, bounds)|
          since = Filterable::Datable.parse(bounds[:since])
          next sub_scope unless since

          sub_scope.where(scope.arel_table[column].lteq(since))
        end
      end
    end
  end
end
