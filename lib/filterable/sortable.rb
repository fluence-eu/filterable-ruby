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

      terms(params, scope).reduce(scope) do |sorted, (sign, column, _term)|
        sorted.order(column => DIRECTIONS[sign])
      end
    end

    # The sort terms {call} would honor, rejoined as sent.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being ordered.
    # @return [Hash] +{ sort: '<accepted terms>' }+, or empty when none is declared.
    def applied(params, scope)
      accepted = terms(params, scope).map { |_sign, _column, term| term }
      accepted.empty? ? {} : { sort: accepted.join(',') }
    end

    # The declared sort terms, each resolved to its direction sign and DB column.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being ordered.
    # @return [Array<Array(String, Object, String)>] sign, DB column and raw term.
    def terms(params, scope)
      return [] unless params[:sort].is_a?(String)

      params[:sort].split(',').filter_map do |raw|
        term = raw.strip
        sign, name = split_direction(term)
        column = scope.sortable_attribute_names[name]
        [sign, column, term] if column && !column.is_a?(Hash)
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
