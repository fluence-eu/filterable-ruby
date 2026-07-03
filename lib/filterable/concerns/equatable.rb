# frozen_string_literal: true

module Filterable
  module Concerns
    # Adds equality filtering to a Filterable::Concern model. Declare the columns
    # with +equatable :reference+ (or +equatable public_name: :db_column+ to
    # alias), then +filters[<attribute>]+ compares with +=+ (scalar value) or
    # +IN+ (array value) on those columns only.
    module Equatable
      extend ActiveSupport::Concern

      included do
        add_filter Filterable::Equatable
      end

      class_methods do
        # The declared equatable attributes, mapping each public name to its DB
        # column, cloned from the superclass so a subclass starts with its
        # parent's declarations and can append its own.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => DB column.
        def equatable_attribute_names
          @equatable_attribute_names ||=
            if superclass.respond_to?(:equatable_attribute_names)
              superclass.equatable_attribute_names.clone
            else
              {}.with_indifferent_access
            end
        end

        # Declares one or more attributes as equatable. A bare name maps onto its
        # own column; a hash aliases a public name to a different column.
        #
        # @api public
        # @param attribute_names [Array<Symbol, String, Hash>] the columns to expose.
        # @return [self] so calls can be chained.
        def equatable(*attribute_names)
          attribute_names.flatten.each do |attribute_name|
            equatable_attribute_names.merge!(Filterable::AttributeNormalization.normalize(attribute_name))
          end

          self
        end
      end
    end
  end
end
