# frozen_string_literal: true

module Filterable
  # Checks a model's declarations against its actual columns and scopes, so a
  # typo in a declaration — a silent no-op at runtime by design — can be caught
  # by a spec:
  #
  #   expect(MovementDetail.filterable_declarations).to be_valid
  #
  # Never used by the engine at runtime: filtering stays a silent no-op on
  # unknown attributes.
  class DeclarationsValidator
    # The column-backed declaration DSLs to check, each exposing
    # +<kind>_attribute_names+ on the model. A kind the model does not respond
    # to is skipped.
    KINDS = %i[datable sortable equatable rangeable].freeze

    # The scope-backed declaration DSLs to check, each exposing
    # +<kind>_scope_names+ on the model. A kind the model does not respond to
    # is skipped.
    SCOPE_KINDS = %i[scopable togglable].freeze

    # The attachment-backed declaration DSLs to check, each exposing
    # +<kind>_attachment_names+ on the model. A kind the model does not respond
    # to is skipped.
    ATTACHMENT_KINDS = %i[attachable].freeze

    # Builds a validator over one model's declarations.
    #
    # @api public
    # @param model [Class] an ActiveRecord model using the declaration DSLs.
    def initialize(model)
      @model = model
    end

    # Whether every declaration maps onto an existing column or scope.
    #
    # @api public
    # @return [Boolean]
    def valid?
      errors.empty?
    end

    # The declarations pointing to unknown columns or scopes, as human-readable
    # messages.
    #
    # @api public
    # @return [Array<String>] one message per broken declaration; empty when valid.
    def errors
      @errors ||= KINDS.flat_map { |kind| column_errors(kind) } +
                  SCOPE_KINDS.flat_map { |kind| scope_errors(kind) } +
                  ATTACHMENT_KINDS.flat_map { |kind| attachment_errors(kind) }
    end

    private

    # The error messages for one column-backed declaration DSL.
    #
    # @api private
    # @param kind [Symbol] the declaration DSL to check.
    # @return [Array<String>] one message per declaration of that kind whose
    #   target does not check out.
    def column_errors(kind)
      reader = "#{kind}_attribute_names"
      return [] unless @model.respond_to?(reader)

      @model.public_send(reader).filter_map do |public_name, target|
        target_error(kind, public_name, target)
      end
    end

    # The error for one declared target, nil when it checks out.
    #
    # @api private
    # @param kind [Symbol] the declaration DSL being checked.
    # @param public_name [Object] the declared public name.
    # @param target [Object] the declared target — a column, or an association path.
    # @return [String, nil] the error message, or nil.
    def target_error(kind, public_name, target)
      return column_error(kind, public_name, @model, target) unless target.is_a?(Hash)
      return "#{kind}: '#{public_name}' cannot sort through an association" if kind == :sortable

      path_error(kind, public_name, target)
    end

    # The error for one association-path target, nil when it checks out.
    #
    # @api private
    # @param kind [Symbol] the declaration DSL being checked.
    # @param public_name [Object] the declared public name.
    # @param target [Hash] the declared association path.
    # @return [String, nil] the error message, or nil.
    def path_error(kind, public_name, target)
      path, column = Filterable::Target.unpack(target)
      if column.is_a?(Hash) || path.empty?
        return "#{kind}: '#{public_name}' has an ambiguous association target on #{@model.name}"
      end

      resolution = Filterable::Target.resolve(@model, path)
      return column_error(kind, public_name, resolution[:klass], column) if resolution

      "#{kind}: '#{public_name}' walks an unresolvable association path '#{path.join(".")}' on #{@model.name}"
    end

    # The error for a column expected on a model, nil when it exists.
    #
    # @api private
    # @param kind [Symbol] the declaration DSL being checked.
    # @param public_name [Object] the declared public name.
    # @param klass [Class] the model expected to own the column.
    # @param column [Object] the declared column.
    # @return [String, nil] the error message, or nil.
    def column_error(kind, public_name, klass, column)
      return if klass.column_names.include?(column.to_s)

      "#{kind}: '#{public_name}' maps to unknown column '#{column}' on #{klass.name}"
    end

    # The error messages for one scope-backed declaration DSL.
    #
    # @api private
    # @param kind [Symbol] the declaration DSL to check.
    # @return [Array<String>] one message per declaration of that kind whose
    #   scope does not exist.
    def scope_errors(kind)
      reader = "#{kind}_scope_names"
      return [] unless @model.respond_to?(reader)

      @model.public_send(reader).filter_map do |public_name, scope_name|
        next if !scope_name.is_a?(Hash) && @model.respond_to?(scope_name)

        "#{kind}: '#{public_name}' maps to unknown scope '#{scope_name}' on #{@model.name}"
      end
    end

    # The error messages for one attachment-backed declaration DSL.
    #
    # @api private
    # @param kind [Symbol] the declaration DSL to check.
    # @return [Array<String>] one message per declaration of that kind whose
    #   generated attachment associations do not exist.
    def attachment_errors(kind)
      reader = "#{kind}_attachment_names"
      return [] unless @model.respond_to?(reader)

      @model.public_send(reader).filter_map do |public_name, attachment|
        next if [:"#{attachment}_attachment", :"#{attachment}_attachments"]
                .any? { |name| @model.reflect_on_association(name) }

        "#{kind}: '#{public_name}' maps to unknown attachment '#{attachment}' on #{@model.name}"
      end
    end
  end
end
