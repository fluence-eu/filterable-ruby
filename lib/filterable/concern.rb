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

      # The default filter params declared on this class, cloned from the
      # superclass so a subclass starts with its parent's defaults and can
      # append its own.
      #
      # @api private
      # @return [ActiveSupport::HashWithIndifferentAccess] public name => default value.
      def default_filter_params
        @default_filter_params ||=
          if superclass.respond_to?(:default_filter_params)
            superclass.default_filter_params.clone
          else
            {}.with_indifferent_access
          end
      end

      # Declares default filter params, used whenever the request carries no
      # value for their key — a present key, even blank, suppresses its default.
      # A Proc value is evaluated lazily at each call, and one returning nil
      # withdraws its default. Defaults go through the same whitelisted fold as
      # request params, so a default on an undeclared name narrows nothing.
      #
      # @api public
      # @param defaults [Hash] public name => default value, or a Proc returning it.
      # @return [self] so calls can be chained.
      def default_filters(defaults)
        default_filter_params.merge!(defaults) if defaults.is_a?(Hash)
        self
      end

      # Folds every registered filter over the relation, narrowing it from the
      # nested +filters+ params merged over the declared defaults. Returns +all+
      # untouched when neither carries anything usable.
      #
      # The optional context hash is handed, as given, to every filter whose
      # callable accepts a third argument — +Model.filterable(params, user_id:
      # current_user.id)+ — so a custom filter can depend on the caller without
      # global state. Two-argument filters, the built-in ones included, never
      # see it.
      #
      # @api public
      # @param params [Hash, ActionController::Parameters] request params, read at +params[:filters]+.
      # @param context [Hash] caller-provided context for context-aware filters.
      # @return [ActiveRecord::Relation] the filtered relation.
      def filterable(params = {}, context = {})
        filters_params = effective_filters(params)
        return all if filters_params.empty?

        filters.reduce(all) { |scope, filter| apply_filter(filter, filters_params, scope, context) || scope }
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
      # @param context [Hash] caller-provided context for context-aware filters.
      # @return [ActiveSupport::HashWithIndifferentAccess] public name => accepted value.
      def applied_filters(params = {}, context = {})
        filters_params = effective_filters(params)
        report = {}.with_indifferent_access
        return report if filters_params.empty?

        filters.select { |filter| filter.respond_to?(:applied) }
               .reduce(report) { |acc, filter| acc.deep_merge(report_from(filter, filters_params, context)) }
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

      # Calls one filter, handing it the context when its +call+ accepts a
      # third argument.
      #
      # @api private
      # @param filter [#call] the registered filter.
      # @param filters_params [ActiveSupport::HashWithIndifferentAccess] the effective +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being narrowed.
      # @param context [Hash] the caller-provided context.
      # @return [ActiveRecord::Relation, nil] the filter's return value.
      def apply_filter(filter, filters_params, scope, context)
        if context_aware?(filter, :call)
          filter.call(filters_params, scope, context)
        else
          filter.call(filters_params, scope)
        end
      end

      # Collects one filter's report, handing it the context when its +applied+
      # accepts a third argument.
      #
      # @api private
      # @param filter [#applied] the registered filter.
      # @param filters_params [ActiveSupport::HashWithIndifferentAccess] the effective +filters+ params.
      # @param context [Hash] the caller-provided context.
      # @return [Hash] the filter's report.
      def report_from(filter, filters_params, context)
        if context_aware?(filter, :applied)
          filter.applied(filters_params, all, context)
        else
          filter.applied(filters_params, all)
        end
      end

      # Whether a filter's callable accepts a third positional argument — an
      # exact three-parameter signature, or a negative arity whose required
      # parameters leave room for one (optional argument or splat).
      #
      # @api private
      # @param filter [Object] the registered filter.
      # @param method_name [Symbol] +:call+ or +:applied+.
      # @return [Boolean]
      def context_aware?(filter, method_name)
        arity = filter.is_a?(Proc) ? filter.arity : filter.method(method_name).arity
        arity == 3 || (arity.negative? && arity >= -4)
      end

      # The request filters merged over the evaluated defaults — the single
      # params shape handed to every filter by {filterable} and
      # {applied_filters}, so the two cannot drift. A key present in the
      # request, even blank, wins over its default.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] request params, read at +params[:filters]+.
      # @return [ActiveSupport::HashWithIndifferentAccess] the effective +filters+ params.
      def effective_filters(params)
        params = params.with_indifferent_access if params.is_a?(Hash)
        requested = indifferent?(params) && indifferent?(params[:filters]) ? params[:filters] : {}
        requested = requested.to_unsafe_h if requested.respond_to?(:to_unsafe_h)
        evaluated_defaults.merge(requested)
      end

      # The declared defaults with every Proc evaluated, nil results withdrawn.
      #
      # @api private
      # @return [ActiveSupport::HashWithIndifferentAccess] public name => default value.
      def evaluated_defaults
        default_filter_params.each_with_object({}.with_indifferent_access) do |(name, value), defaults|
          resolved = value.respond_to?(:call) ? value.call : value
          defaults[name] = resolved unless resolved.nil?
        end
      end

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
