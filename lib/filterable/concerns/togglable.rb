# frozen_string_literal: true

module Filterable
  module Concerns
    # Adds scope toggling to a Filterable::Concern model. Declare the
    # no-argument scopes with +togglable :priced+ (or +togglable public_name:
    # :scope_name+ to alias), then a strict true under +filters[<name>]+
    # applies those scopes only — checkbox semantics.
    module Togglable
      extend ActiveSupport::Concern

      included do
        add_filter Filterable::Togglable
      end

      class_methods do
        # The declared togglable names, mapping each public name to its scope,
        # cloned from the superclass so a subclass starts with its parent's
        # declarations and can append its own.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => scope name.
        def togglable_scope_names
          @togglable_scope_names ||=
            if superclass.respond_to?(:togglable_scope_names)
              superclass.togglable_scope_names.clone
            else
              {}.with_indifferent_access
            end
        end

        # Declares one or more scopes as togglable. A bare name maps onto the
        # scope of the same name; a hash aliases a public name to a different
        # scope.
        #
        # @api public
        # @param scope_names [Array<Symbol, String, Hash>] the scopes to expose.
        # @return [self] so calls can be chained.
        def togglable(*scope_names)
          scope_names.flatten.each do |scope_name|
            togglable_scope_names.merge!(Filterable::AttributeNormalization.normalize(scope_name))
          end

          self
        end
      end
    end
  end
end
