# frozen_string_literal: true

module Filterable
  module Datable
    # Keeps rows whose datable attribute is strictly after the bound.
    # Reads +filters[<attribute>][after]+.
    module After
      module_function

      # Narrows the scope to rows strictly after each declared attribute's +after+ bound.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        Filterable::Datable.columns(params, scope).reduce(scope) do |sub_scope, (column, bounds)|
          after = Filterable::Datable.parse(bounds[:after])
          next sub_scope unless after

          sub_scope.where(scope.arel_table[column].gt(after))
        end
      end
    end
  end
end
