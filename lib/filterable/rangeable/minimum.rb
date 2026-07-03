# frozen_string_literal: true

module Filterable
  module Rangeable
    # Keeps rows whose rangeable attribute is at least the bound (inclusive).
    # Reads +filters[<attribute>][min]+.
    module Minimum
      module_function

      # Narrows the scope to rows at or above each declared attribute's +min+ bound.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        entries = Filterable::Rangeable.accepted(params, scope, :min)
        entries.reduce(scope) do |sub_scope, (_name, target, _bounds, parsed)|
          Filterable::Target.narrow(sub_scope, target) { |field| field.gteq(parsed[:min]) }
        end
      end

      # The bounds {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted +min+ bound.
      def applied(params, scope)
        entries = Filterable::Rangeable.accepted(params, scope, :min)
        entries.each_with_object({}) do |(name, _column, bounds, _parsed), report|
          report[name] = bounds.slice(:min)
        end
      end
    end
  end
end
