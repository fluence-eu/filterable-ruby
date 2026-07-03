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
                  SCOPE_KINDS.flat_map { |kind| scope_errors(kind) }
    end

    private

    # The error messages for one column-backed declaration DSL.
    #
    # @api private
    # @param kind [Symbol] the declaration DSL to check.
    # @return [Array<String>] one message per declaration of that kind whose
    #   column does not exist.
    def column_errors(kind)
      reader = "#{kind}_attribute_names"
      return [] unless @model.respond_to?(reader)

      @model.public_send(reader).filter_map do |public_name, column|
        next if @model.column_names.include?(column.to_s)

        "#{kind}: '#{public_name}' maps to unknown column '#{column}' on #{@model.name}"
      end
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
        next if @model.respond_to?(scope_name)

        "#{kind}: '#{public_name}' maps to unknown scope '#{scope_name}' on #{@model.name}"
      end
    end
  end
end
