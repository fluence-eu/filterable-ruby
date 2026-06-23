# frozen_string_literal: true

module Filterable
  module Datable
    # Keeps rows whose datable attribute is strictly before the bound.
    # Reads +filters[<attribute>][before]+.
    module Before
      module_function

      def call(params, scope)
        Filterable::Datable.columns(params, scope).reduce(scope) do |sub_scope, (column, bounds)|
          before = Filterable::Datable.parse(bounds[:before])
          next sub_scope unless before

          sub_scope.where(scope.arel_table[column].lt(before))
        end
      end
    end
  end
end
