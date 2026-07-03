# frozen_string_literal: true

module Filterable
  module Concerns
    # Adds ActiveStorage attachment filtering to a Filterable::Concern model.
    # Declare the attachments with +attachable :document+ (or +attachable
    # public_name: :attachment_name+ to alias), then the present/type/min_size/
    # max_size keys under +filters[<name>]+ operate on those attachments only.
    module Attachable
      extend ActiveSupport::Concern

      included do
        add_filter Filterable::Attachable
      end

      class_methods do
        # The declared attachable names, mapping each public name to its
        # attachment, cloned from the superclass so a subclass starts with its
        # parent's declarations and can append its own.
        #
        # @api private
        # @return [ActiveSupport::HashWithIndifferentAccess] public name => attachment name.
        def attachable_attachment_names
          @attachable_attachment_names ||=
            if superclass.respond_to?(:attachable_attachment_names)
              superclass.attachable_attachment_names.clone
            else
              {}.with_indifferent_access
            end
        end

        # Declares one or more attachments as attachable. A bare name maps onto
        # the attachment of the same name; a hash aliases a public name to a
        # different attachment.
        #
        # @api public
        # @param attachment_names [Array<Symbol, String, Hash>] the attachments to expose.
        # @return [self] so calls can be chained.
        def attachable(*attachment_names)
          attachment_names.flatten.each do |attachment_name|
            attachable_attachment_names.merge!(Filterable::AttributeNormalization.normalize(attachment_name))
          end

          self
        end
      end
    end
  end
end
