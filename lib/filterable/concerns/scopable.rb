# frozen_string_literal: true

module Filterable
  module Concerns
    # Adds scope delegation to a Filterable::Concern model. Declare the scopes
    # with +scopable :cheaper_than+ (or +scopable public_name: :scope_name+ to
    # alias), then +filters[<name>]+ hands its value to those scopes only.
    module Scopable
      extend ActiveSupport::Concern

      included do
        add_filter Filterable::Scopable
      end

      class_methods do
        # The declared scopable names, mapping each public name to its scope,
        # cloned from the superclass so a subclass starts with its parent's
        # declarations and can append its own.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => scope name.
        def scopable_scope_names
          @scopable_scope_names ||=
            if superclass.respond_to?(:scopable_scope_names)
              superclass.scopable_scope_names.clone
            else
              {}.with_indifferent_access
            end
        end

        # Declares one or more scopes as scopable. A bare name maps onto the
        # scope of the same name; a hash aliases a public name to a different
        # scope.
        #
        # @api public
        # @param scope_names [Array<Symbol, String, Hash>] the scopes to expose.
        # @return [self] so calls can be chained.
        def scopable(*scope_names)
          scope_names.flatten.each do |scope_name|
            scopable_scope_names.merge!(Filterable::AttributeNormalization.normalize(scope_name))
          end

          self
        end
      end
    end
  end
end
