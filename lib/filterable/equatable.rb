# frozen_string_literal: true

module Filterable
  # Narrows a relation by equality from +filters[<attribute>]+. Only attributes
  # the model declared +equatable+ are honored: a scalar value compares with
  # +=+ and an array of scalars with +IN+. A blank or non-scalar value (e.g. a
  # hash injected through the query string) narrows nothing.
  module Equatable
    module_function

    # Narrows the scope to rows whose declared equatable attributes equal the
    # given values.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def call(params, scope)
      declared = scope.equatable_attribute_names
      accepted(params, scope).reduce(scope) do |sub_scope, (name, value)|
        sub_scope.where(declared[name] => value)
      end
    end

    # The values {call} would apply, keyed by public name, normalized.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => Object}] public name => accepted value.
    def applied(params, scope)
      accepted(params, scope).to_h
    end

    # The entries of {values} whose value normalizes to something usable — the
    # single place deciding whether an equality applies, so {call} and {applied}
    # cannot drift.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Array<Array(Object, Object)>] public name and normalized value.
    def accepted(params, scope)
      values(params, scope).filter_map do |name, raw|
        value = Filterable::ValueNormalization.normalize(raw)
        [name, value] unless value.nil?
      end
    end

    # Whitelist the params to the declared equatable attributes, keeping their
    # public names and raw values.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => Object}] public name => raw value.
    def values(params, scope)
      sliced = params.slice(*scope.equatable_attribute_names.keys)
      sliced.respond_to?(:to_unsafe_h) ? sliced.to_unsafe_h : sliced
    end
  end
end
