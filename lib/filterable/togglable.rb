# frozen_string_literal: true

module Filterable
  # Applies a no-argument model scope when +filters[<name>]+ is present as a
  # bare key (+?filters[priced]+, +filters[priced]=+) or carries a strict true
  # value. Only names the model declared +togglable+ are honored; the scope
  # name is fixed at declaration time, never derived from the params. An
  # explicit false value (+'false'+, +'0'+ — what Rails' +check_box+ hidden
  # field submits), an arbitrary string, a missing scope, or a scope not
  # returning a relation narrows nothing.
  module Togglable
    # The explicit values that switch a toggle on. A strict allowlist, unlike
    # +ActiveModel::Type::Boolean+ where any unrecognized string casts to true.
    TRUE_VALUES = [true, 1, '1', 'true'].freeze

    # The explicit values that switch a toggle off — what Rails' +check_box+
    # hidden field submits. The shared vocabulary for every boolean-ish param
    # in the gem.
    FALSE_VALUES = [false, 0, '0', 'false'].freeze

    module_function

    # Narrows the scope by applying each toggled-on declared scope.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def call(params, scope)
      accepted(params, scope).reduce(scope) do |sub_scope, (_name, scope_name)|
        narrowed = sub_scope.public_send(scope_name)
        narrowed.is_a?(ActiveRecord::Relation) ? narrowed : sub_scope
      end
    end

    # The toggles {call} would apply, keyed by public name, always +true+.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => true}] public name => true.
    def applied(params, scope)
      accepted(params, scope).each_with_object({}) do |(name, _scope_name), report|
        report[name] = true
      end
    end

    # The declared entries whose key is toggled on and whose scope exists — the
    # single place deciding whether a toggle applies, so {call} and {applied}
    # cannot drift.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Array<Array(Object, Object)>] public name and scope name.
    def accepted(params, scope)
      declared = scope.togglable_scope_names
      sliced = params.slice(*declared.keys)
      sliced = sliced.to_unsafe_h if sliced.respond_to?(:to_unsafe_h)
      sliced.filter_map do |name, raw|
        scope_name = declared[name]
        next unless toggled_on?(raw) && !scope_name.is_a?(Hash) && scope.respond_to?(scope_name)

        [name, scope_name]
      end
    end

    # Whether a present key's value switches the toggle on: a bare key (nil or
    # a blank string) counts as on, everything else must be a strict true.
    #
    # @api private
    # @param value [Object] the raw value under the present key.
    # @return [Boolean]
    def toggled_on?(value)
      case value
      when nil
        true
      when String
        value.strip.empty? || TRUE_VALUES.include?(value)
      else
        TRUE_VALUES.include?(value)
      end
    end

    # Whether a value is an explicit off.
    #
    # @api private
    # @param value [Object] the raw value.
    # @return [Boolean]
    def toggled_off?(value)
      FALSE_VALUES.include?(value)
    end
  end
end
