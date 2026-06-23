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
        def sortable_attribute_names
          @sortable_attribute_names ||= {}.with_indifferent_access
        end

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
