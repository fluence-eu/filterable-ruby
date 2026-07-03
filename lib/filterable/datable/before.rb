# frozen_string_literal: true

module Filterable
  module Datable
    # Keeps rows whose datable attribute is strictly before the bound.
    # Reads +filters[<attribute>][before]+.
    module Before
      module_function

      # Narrows the scope to rows strictly before each declared attribute's +before+ bound.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        entries = Filterable::Datable.accepted(params, scope, :before)
        entries.reduce(scope) do |sub_scope, (_name, target, _bounds, parsed)|
          Filterable::Target.narrow(sub_scope, target) { |field| field.lt(parsed[:before]) }
        end
      end

      # The bounds {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted +before+ bound.
      def applied(params, scope)
        entries = Filterable::Datable.accepted(params, scope, :before)
        entries.each_with_object({}) do |(name, _column, bounds, _parsed), report|
          report[name] = bounds.slice(:before)
        end
      end
    end
  end
end
