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
        entries = Filterable::Datable.accepted(params, scope, :after)
        entries.reduce(scope) do |sub_scope, (_name, column, _bounds, parsed)|
          sub_scope.where(scope.arel_table[column].gt(parsed[:after]))
        end
      end

      # The bounds {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted +after+ bound.
      def applied(params, scope)
        entries = Filterable::Datable.accepted(params, scope, :after)
        entries.each_with_object({}) do |(name, _column, bounds, _parsed), report|
          report[name] = bounds.slice(:after)
        end
      end
    end
  end
end
