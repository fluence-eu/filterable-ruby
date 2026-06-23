# frozen_string_literal: true

module Filterable
  module Datable
    # Keeps rows whose datable attribute is strictly after the bound.
    # Reads +filters[<attribute>][after]+.
    module After
      module_function

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
