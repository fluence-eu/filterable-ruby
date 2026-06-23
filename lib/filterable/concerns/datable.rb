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
        def datable_attribute_names
          @datable_attribute_names ||= {}.with_indifferent_access
        end

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
