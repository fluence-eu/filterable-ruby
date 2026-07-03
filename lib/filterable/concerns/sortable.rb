# frozen_string_literal: true

module Filterable
  module Concerns
    # Adds ordering to a Filterable::Concern model. Declare the sortable columns with
    # +sortable :value_date+ (or +sortable public_name: :db_column+ to alias), then
    # +filters[sort]+ may order on those columns only.
    module Sortable
      extend ActiveSupport::Concern

      included do
        add_filter Filterable::Sortable
      end

      class_methods do
        # The declared sortable attributes, mapping each public name to its DB column,
        # cloned from the superclass so a subclass starts with its parent's
        # declarations and can append its own.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => DB column.
        def sortable_attribute_names
          @sortable_attribute_names ||=
            if superclass.respond_to?(:sortable_attribute_names)
              superclass.sortable_attribute_names.clone
            else
              {}.with_indifferent_access
            end
        end

        # Declares one or more attributes as sortable. A bare name maps onto its own
        # column; a hash aliases a public name to a different column.
        #
        # @api public
        # @param attribute_names [Array<Symbol, String, Hash>] the columns to expose.
        # @return [self] so calls can be chained.
        def sortable(*attribute_names)
          attribute_names.flatten.each do |attribute_name|
            sortable_attribute_names.merge!(Filterable::AttributeNormalization.normalize(attribute_name))
          end

          self
        end
      end
    end
  end
end
