# frozen_string_literal: true

module Filterable
  module Concerns
    # Adds numeric bound filtering to a Filterable::Concern model. Declare the
    # columns with +rangeable :gross_amount_cents+ (or +rangeable public_name:
    # :db_column+ to alias), then the min/max filters operate on those columns
    # only, both bounds inclusive.
    module Rangeable
      extend ActiveSupport::Concern

      included do
        add_filter Filterable::Rangeable::Minimum
        add_filter Filterable::Rangeable::Maximum
      end

      class_methods do
        # The declared rangeable attributes, mapping each public name to its DB
        # column, cloned from the superclass so a subclass starts with its
        # parent's declarations and can append its own.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => DB column.
        def rangeable_attribute_names
          @rangeable_attribute_names ||=
            if superclass.respond_to?(:rangeable_attribute_names)
              superclass.rangeable_attribute_names.clone
            else
              {}.with_indifferent_access
            end
        end

        # Declares one or more attributes as rangeable. A bare name maps onto its
        # own column; a hash aliases a public name to a different column.
        #
        # @api public
        # @param attribute_names [Array<Symbol, String, Hash>] the columns to expose.
        # @return [self] so calls can be chained.
        def rangeable(*attribute_names)
          attribute_names.flatten.each do |attribute_name|
            rangeable_attribute_names.merge!(Filterable::AttributeNormalization.normalize(attribute_name))
          end

          self
        end
      end
    end
  end
end
