# frozen_string_literal: true

module Filterable
  module Concerns
    # Adds date filtering to a Filterable::Concern model. Declare the date columns
    # with +datable :value_date+ (or +datable public_name: :db_column+ to alias),
    # then the after/before/range/since filters operate on those columns only.
    module Datable
      extend ActiveSupport::Concern

      included do
        add_filter Filterable::Datable::After
        add_filter Filterable::Datable::Before
        add_filter Filterable::Datable::Range
        add_filter Filterable::Datable::Since
      end

      class_methods do
        # The declared datable attributes, mapping each public name to its DB column,
        # cloned from the superclass so a subclass starts with its parent's
        # declarations and can append its own.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => DB column.
        def datable_attribute_names
          @datable_attribute_names ||=
            if superclass.respond_to?(:datable_attribute_names)
              superclass.datable_attribute_names.clone
            else
              {}.with_indifferent_access
            end
        end

        # Declares one or more attributes as datable. A bare name maps onto its own
        # column; a hash aliases a public name to a different column.
        #
        # @api public
        # @param attribute_names [Array<Symbol, String, Hash>] the columns to expose.
        # @return [self] so calls can be chained.
        def datable(*attribute_names)
          attribute_names.flatten.each do |attribute_name|
            datable_attribute_names.merge!(Filterable::AttributeNormalization.normalize(attribute_name))
          end

          self
        end
      end
    end
  end
end
