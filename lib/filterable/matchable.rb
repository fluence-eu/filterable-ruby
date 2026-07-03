# frozen_string_literal: true

module Filterable
  # Namespace for the partial match filters and the helpers they share. The
  # user's term is always LIKE-escaped (+%+ and +_+ match literally) and the
  # wildcard placement is fixed by the declarative key — the caller never
  # controls the pattern. Matching is case insensitive by default; a
  # declaration may opt into sensitivity with +case_sensitive: true+.
  module Matchable
    # The LIKE escape character, matching what +sanitize_sql_like+ emits.
    ESCAPE = '\\'

    module_function

    # Whitelist the params to the declared matchable attributes, keeping their
    # public names. An attribute whose value is not a hash of terms is dropped,
    # so a malformed shape narrows nothing instead of raising.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => Hash}] public name => raw terms for that attribute.
    def bounds(params, scope)
      sliced = params.slice(*scope.matchable_attribute_names.keys)
      sliced = sliced.to_unsafe_h if sliced.respond_to?(:to_unsafe_h)
      sliced.select { |_name, value| value.is_a?(Hash) }
    end

    # The entries of {bounds} whose given key carries a usable term — the
    # single place deciding whether a match applies, so the filters' +call+
    # and +applied+ cannot drift.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @param key [Symbol] the match key the filter reads.
    # @return [Array<Array(Object, Object, String)>] public name, target and raw term.
    def accepted(params, scope, key)
      declared = scope.matchable_attribute_names
      bounds(params, scope).filter_map do |name, terms|
        term = terms[key]
        [name, declared[name], term] if term.is_a?(String) && term.present?
      end
    end

    # LIKE-escapes a user term so its +%+ and +_+ match literally.
    #
    # @api private
    # @param term [String] the raw term.
    # @return [String] the escaped term.
    def escape(term)
      ActiveRecord::Base.sanitize_sql_like(term)
    end

    # Narrows the scope with a LIKE pattern on the target's column, case
    # sensitive when the attribute was declared so.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @param name [Object] the declared public name.
    # @param target [Symbol, String, Hash] the declared target.
    # @param pattern [String] the escaped LIKE pattern.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def narrow(sub_scope, scope, name, target, pattern)
      sensitive = scope.matchable_case_sensitive[name] ? true : false
      Filterable::Target.narrow(sub_scope, target) { |field| field.matches(pattern, ESCAPE, sensitive) }
    end
  end
end
