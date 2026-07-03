# frozen_string_literal: true

module Filterable
  module Concerns
    # Adds partial matching to a Filterable::Concern model. Declare the columns
    # with +matchable :reference+ (or +matchable public_name: :db_column+ to
    # alias), then the starts_with/ends_with/contains keys under
    # +filters[<attribute>]+ operate on those columns only. +case_sensitive:
    # true+ in a declaration makes its attributes match case sensitively —
    # +case_sensitive+ is a reserved word, never a public name.
    module Matchable
      extend ActiveSupport::Concern

      included do
        add_filter Filterable::Matchable::StartsWith
        add_filter Filterable::Matchable::EndsWith
        add_filter Filterable::Matchable::Contains
      end

      class_methods do
        # The declared matchable attributes, mapping each public name to its DB
        # column, cloned from the superclass so a subclass starts with its
        # parent's declarations and can append its own.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => DB column.
        def matchable_attribute_names
          @matchable_attribute_names ||=
            if superclass.respond_to?(:matchable_attribute_names)
              superclass.matchable_attribute_names.clone
            else
              {}.with_indifferent_access
            end
        end

        # The declared attributes matching case sensitively, cloned from the
        # superclass like the declarations themselves.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => true.
        def matchable_case_sensitive
          @matchable_case_sensitive ||=
            if superclass.respond_to?(:matchable_case_sensitive)
              superclass.matchable_case_sensitive.clone
            else
              {}.with_indifferent_access
            end
        end

        # Declares one or more attributes as matchable. A bare name maps onto
        # its own column; a hash aliases a public name to a different column;
        # +case_sensitive: true+ applies to every name of the call.
        #
        # @api public
        # @param attribute_names [Array<Symbol, String, Hash>] the columns to expose.
        # @return [self] so calls can be chained.
        def matchable(*attribute_names)
          declared, sensitive = split_matchable_options(attribute_names)
          matchable_attribute_names.merge!(declared)
          declared.each_key { |name| matchable_case_sensitive[name] = true } if sensitive

          self
        end

        private

        # Splits a matchable call into its declarations and its options.
        #
        # @api private
        # @param attribute_names [Array<Symbol, String, Hash>] the raw declarations.
        # @return [Array(Hash, Boolean)] public name => column, and the
        #   call-wide case sensitivity.
        def split_matchable_options(attribute_names)
          declared = {}
          sensitive = false
          attribute_names.flatten.each do |attribute_name|
            declaration = Filterable::AttributeNormalization.normalize(attribute_name).dup
            sensitive = true if declaration.delete(:case_sensitive)
            declared.merge!(declaration)
          end
          [declared, sensitive]
        end
      end
    end
  end
end
