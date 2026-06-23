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
      # The filters registered on this class, cloned from the superclass so a
      # subclass starts with its parent's filters and can append its own.
      #
      # @api private
      # @return [Array<#call>] the ordered list of registered filters.
      def filters
        @filters ||= superclass.respond_to?(:filters) ? superclass.filters.clone : []
      end

      # Registers a filter, applied in registration order by {filterable}.
      #
      # @api public
      # @param filter [#call, nil] any object responding to +call(filters_params, scope)+.
      # @yield [filters_params, scope] an inline filter, used when no object is given.
      # @return [self] so calls can be chained.
      def add_filter(filter = nil, &block)
        if block_given?
          filters << block
        elsif filter.respond_to?(:call)
          filters << filter
        end

        self
      end

      # Folds every registered filter over the relation, narrowing it from the
      # nested +filters+ params. Returns +all+ untouched when the params carry no
      # usable +filters+ key.
      #
      # @api public
      # @param params [Hash, ActionController::Parameters] request params, read at +params[:filters]+.
      # @return [ActiveRecord::Relation] the filtered relation.
      def filterable(params = {})
        params = params.with_indifferent_access if params.is_a?(Hash)
        return all unless indifferent?(params) && indifferent?(params[:filters])

        filters.reduce(all) { |scope, filter| filter.call(params[:filters], scope) || scope }
      end

      private

      # Whether the value carries indifferent string/symbol access, i.e. an
      # ActionController::Parameters (duck-typed) or a HashWithIndifferentAccess.
      #
      # @api private
      # @param value [Object] the candidate params object.
      # @return [Boolean]
      def indifferent?(value)
        value.respond_to?(:to_unsafe_h) ||
          value.is_a?(ActiveSupport::HashWithIndifferentAccess)
      end
    end
  end
end
