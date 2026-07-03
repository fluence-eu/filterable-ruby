# frozen_string_literal: true

module Filterable
  module Matchable
    # Keeps rows whose matchable attribute contains the term. Full scan — the
    # leading wildcard defeats indexes. Reads +filters[<attribute>][contains]+.
    module Contains
      module_function

      # Narrows the scope to rows containing each declared attribute's term.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        entries = Filterable::Matchable.accepted(params, scope, :contains)
        entries.reduce(scope) do |sub_scope, (name, target, term)|
          pattern = "%#{Filterable::Matchable.escape(term)}%"
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
        entries = Filterable::Matchable.accepted(params, scope, :contains)
        entries.each_with_object({}) do |(name, _target, term), report|
          report[name] = { contains: term }
        end
      end
    end
  end
end
