# frozen_string_literal: true

module Filterable
  # Declarative, whitelisted query filtering for ActiveRecord models.
  #
  # Models opt in with +include Filterable::Concern+ and register filters through
  # +add_filter+ — a block, or any object responding to +call(filters_params, scope)+.
  # The +Filterable::Concerns::*+ mixins layer concrete filters and a declaration DSL
  # on top of this engine. +filterable+ folds every registered filter over the
  # relation, each one narrowing it from the nested +filters+ params.
  module Concern
    extend ActiveSupport::Concern

    class_methods do
      def filters
        @filters ||= superclass.respond_to?(:filters) ? superclass.filters.clone : []
      end

      def add_filter(filter = nil, &block)
        if block_given?
          filters << block
        elsif filter.respond_to?(:call)
          filters << filter
        end

        self
      end

      def filterable(params = {})
        params = params.with_indifferent_access if params.is_a?(Hash)
        return all unless indifferent?(params) && indifferent?(params[:filters])

        filters.reduce(all) { |scope, filter| filter.call(params[:filters], scope) || scope }
      end

      private

      def indifferent?(value)
        value.respond_to?(:to_unsafe_h) ||
          value.is_a?(ActiveSupport::HashWithIndifferentAccess)
      end
    end
  end
end
