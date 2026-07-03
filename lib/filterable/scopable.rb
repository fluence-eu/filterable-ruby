# frozen_string_literal: true

module Filterable
  # Hands +filters[<name>]+ to a named model scope. Only names the model
  # declared +scopable+ are honored; the scope name is fixed at declaration
  # time, never derived from the params. A blank or non-scalar value, a missing
  # scope, or a scope not returning a relation narrows nothing.
  module Scopable
    module_function

    # Narrows the scope by handing each accepted value to its declared scope.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def call(params, scope)
      accepted(params, scope).reduce(scope) do |sub_scope, (_name, scope_name, value)|
        narrowed = sub_scope.public_send(scope_name, value)
        narrowed.is_a?(ActiveRecord::Relation) ? narrowed : sub_scope
      end
    end

    # The values {call} would hand over, keyed by public name, normalized.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => Object}] public name => accepted value.
    def applied(params, scope)
      accepted(params, scope).each_with_object({}) do |(name, _scope_name, value), report|
        report[name] = value
      end
    end

    # The declared entries whose value normalizes to something usable and whose
    # scope exists — the single place deciding whether a delegation applies, so
    # {call} and {applied} cannot drift.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Array<Array(Object, Object, Object)>] public name, scope name and value.
    def accepted(params, scope)
      declared = scope.scopable_scope_names
      sliced = params.slice(*declared.keys)
      sliced = sliced.to_unsafe_h if sliced.respond_to?(:to_unsafe_h)
      sliced.filter_map do |name, raw|
        value = Filterable::ValueNormalization.normalize(raw)
        scope_name = declared[name]
        next if value.nil? || scope_name.is_a?(Hash) || !scope.respond_to?(scope_name)

        [name, scope_name, value]
      end
    end
  end
end
