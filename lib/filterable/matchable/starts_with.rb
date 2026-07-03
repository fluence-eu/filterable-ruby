# frozen_string_literal: true

module Filterable
  module Matchable
    # Keeps rows whose matchable attribute starts with the term — the sargable
    # variant, able to use a B-tree index. Reads +filters[<attribute>][starts_with]+.
    module StartsWith
      module_function

      # Narrows the scope to rows starting with each declared attribute's term.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        entries = Filterable::Matchable.accepted(params, scope, :starts_with)
        entries.reduce(scope) do |sub_scope, (name, target, term)|
          pattern = "#{Filterable::Matchable.escape(term)}%"
          Filterable::Matchable.narrow(sub_scope, scope, name, target, pattern)
        end
      end

      # The terms {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted term.
      def applied(params, scope)
        entries = Filterable::Matchable.accepted(params, scope, :starts_with)
        entries.each_with_object({}) do |(name, _target, term), report|
          report[name] = { starts_with: term }
        end
      end
    end
  end
end
