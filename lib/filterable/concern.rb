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

    # The class-level API, mixed in by ActiveSupport::Concern exactly like the
    # +class_methods do+ block it replaces (kept as a named module so it can
    # grow without hitting block-length limits).
    module ClassMethods
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

      # Reports which filters {filterable} would actually apply from the same
      # params, mapping each public name to the accepted value. Since an unknown
      # or malformed filter is a silent no-op by design, this is how a caller
      # tells the difference — echo the active filters in a response, or diff
      # against +params[:filters]+ to surface what was ignored. Filters report
      # through an optional +applied(filters_params, scope)+; a block filter
      # cannot describe itself and is skipped.
      #
      # @api public
      # @param params [Hash, ActionController::Parameters] request params, read at +params[:filters]+.
      # @return [ActiveSupport::HashWithIndifferentAccess] public name => accepted value.
      def applied_filters(params = {})
        params = params.with_indifferent_access if params.is_a?(Hash)
        report = {}.with_indifferent_access
        return report unless indifferent?(params) && indifferent?(params[:filters])

        filters.select { |filter| filter.respond_to?(:applied) }
               .reduce(report) { |acc, filter| acc.deep_merge(filter.applied(params[:filters], all)) }
      end

      # A validator checking every declaration against the model's columns, meant
      # for specs — at runtime a typo'd declaration stays a silent no-op by design.
      #
      # @api public
      # @return [Filterable::DeclarationsValidator]
      def filterable_declarations
        Filterable::DeclarationsValidator.new(self)
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
