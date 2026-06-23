# frozen_string_literal: true

module Filterable
  module Datable
    # Keeps rows whose datable attribute falls within an inclusive range.
    # Reads +filters[<attribute>][from]+ and +filters[<attribute>][to]+, applied
    # only when both bounds are present and parseable.
    module Range
      module_function

      def call(params, scope)
        Filterable::Datable.columns(params, scope).reduce(scope) do |sub_scope, (column, bounds)|
          from = Filterable::Datable.parse(bounds[:from])
          to = Filterable::Datable.parse(bounds[:to])
          next sub_scope unless from && to

          field = scope.arel_table[column]
          sub_scope.where(field.gteq(from)).where(field.lteq(to))
        end
      end
    end
  end
end
