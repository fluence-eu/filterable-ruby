# frozen_string_literal: true

module Filterable
  # Orders a relation from a comma-separated +filters[sort]+ list, each term
  # optionally prefixed with +/- for asc/desc. Only attributes the model declared
  # +sortable+ are honored; unknown ones are skipped.
  module Sortable
    DIRECTIONS = { '+' => :asc, '-' => :desc }.freeze

    module_function

    def call(params, scope)
      return unless params[:sort].is_a?(String)

      params[:sort].split(',').reduce(scope) do |sorted, term|
        sign, name = split_direction(term.strip)
        column = scope.sortable_attribute_names[name]
        next sorted unless column

        sorted.order(column => DIRECTIONS[sign])
      end
    end

    def split_direction(term)
      return [term[0], term[1..]] if term.start_with?('+', '-')

      ['+', term]
    end
  end
end
