# frozen_string_literal: true

module Filterable
  # Orders a relation from a comma-separated +filters[sort]+ list, each term
  # optionally prefixed with +/- for asc/desc. Only attributes the model declared
  # +sortable+ are honored; unknown ones are skipped.
  module Sortable
    DIRECTIONS = { '+' => :asc, '-' => :desc }.freeze

    module_function

    # Orders the scope from the comma-separated +filters[sort]+ list, honoring only
    # declared sortable attributes.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being ordered.
    # @return [ActiveRecord::Relation, nil] the ordered relation, or nil when there is no sort term.
    def call(params, scope)
      return unless params[:sort].is_a?(String)

      params[:sort].split(',').reduce(scope) do |sorted, term|
        sign, name = split_direction(term.strip)
        column = scope.sortable_attribute_names[name]
        next sorted unless column

        sorted.order(column => DIRECTIONS[sign])
      end
    end

    # Splits a sort term into its direction sign and attribute name, defaulting to
    # ascending when no sign is present.
    #
    # @api private
    # @param term [String] a single sort term, e.g. +"-value_date"+.
    # @return [Array(String, String)] the sign (+"+"+ or +"-"+) and the attribute name.
    def split_direction(term)
      return [term[0], term[1..]] if term.start_with?('+', '-')

      ['+', term]
    end
  end
end
