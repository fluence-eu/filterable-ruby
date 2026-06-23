# frozen_string_literal: true

module Filterable
  # Shared by the datable/sortable declaration DSLs: a bare attribute maps onto
  # its own column, a hash aliases public names to DB columns, anything else
  # is ignored.
  module AttributeNormalization
    module_function

    # Normalizes a single attribute declaration into a public-name => column hash.
    #
    # @api private
    # @param attribute_name [Symbol, String, Hash, Object] the raw declaration.
    # @return [Hash] public name(s) mapped to DB column(s); empty for unsupported input.
    def normalize(attribute_name)
      case attribute_name
      when Hash then attribute_name
      when String, Symbol then { attribute_name => attribute_name }
      else {}
      end
    end
  end
end
