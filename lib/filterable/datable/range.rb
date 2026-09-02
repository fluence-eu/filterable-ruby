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
        entries = Filterable::Datable.accepted(params, scope, :from, :to)
        entries.reduce(scope) do |sub_scope, (_name, target, _bounds, parsed)|
          Filterable::Target.narrow(sub_scope, target) do |field|
            Filterable::Datable.on_or_after(field, parsed[:from])
                               .and(Filterable::Datable.on_or_before(field, parsed[:to]))
          end
        end
      end

      # The bounds {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted +from+/+to+ bounds.
      def applied(params, scope)
        entries = Filterable::Datable.accepted(params, scope, :from, :to)
        entries.each_with_object({}) do |(name, _column, bounds, _parsed), report|
          report[name] = bounds.slice(:from, :to)
        end
      end
    end
  end
end
