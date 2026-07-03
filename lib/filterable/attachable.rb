# frozen_string_literal: true

module Filterable
  # Filters records by their ActiveStorage attachments, declared with
  # +attachable :document+. Reads these nested keys under +filters[<name>]+:
  # +present+ (strict true or bare key keeps attached records, an explicit
  # false keeps unattached ones), +type+ (blob content type, +=+ or +IN+),
  # +min_size+ / +max_size+ (inclusive blob byte size bounds).
  #
  # Everything resolves through the associations +has_one_attached+ /
  # +has_many_attached+ generate (+<name>_attachment(s)+, +<name>_blob(s)+ —
  # Rails' documented contract), so the gem never references ActiveStorage
  # itself; a declared name without those associations narrows nothing.
  module Attachable
    # The explicit values that flip +present+ to its unattached side.
    FALSE_VALUES = [false, 0, '0', 'false'].freeze

    module_function

    # Narrows the scope from each accepted attachment key.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def call(params, scope)
      accepted(params, scope).reduce(scope) do |sub_scope, (_name, attachment, key, value, _raw)|
        apply(sub_scope, attachment, key, value)
      end
    end

    # The attachment keys {call} would apply, grouped by public name, with
    # their raw values.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Hash{Symbol, String => Hash}] public name => accepted keys.
    def applied(params, scope)
      accepted(params, scope).each_with_object({}) do |(name, _attachment, key, _value, raw), report|
        (report[name] ||= {})[key] = raw
      end
    end

    # The declared entries whose keys carry something usable and whose model
    # exposes the generated attachment associations — the single place deciding
    # what applies, so {call} and {applied} cannot drift.
    #
    # @api private
    # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @return [Array<Array(Object, Object, Symbol, Object, Object)>] public
    #   name, attachment name, key, prepared value and raw value.
    def accepted(params, scope)
      declared = scope.attachable_attachment_names
      sliced = params.slice(*declared.keys)
      sliced = sliced.to_unsafe_h if sliced.respond_to?(:to_unsafe_h)
      sliced.flat_map do |name, bounds|
        next [] unless bounds.is_a?(Hash) && attachment_association(scope, declared[name])

        entries(name, declared[name], bounds)
      end
    end

    # The usable entries of one attachment's bounds hash.
    #
    # @api private
    # @param name [Object] the declared public name.
    # @param attachment [Object] the attachment name.
    # @param bounds [Hash] the raw keys under +filters[<name>]+.
    # @return [Array<Array(Object, Object, Symbol, Object, Object)>] the accepted entries.
    def entries(name, attachment, bounds)
      [
        [:present, presence_value(bounds)],
        [:type, Filterable::ValueNormalization.normalize(bounds[:type])],
        [:min_size, Filterable::Rangeable.parse(bounds[:min_size])],
        [:max_size, Filterable::Rangeable.parse(bounds[:max_size])]
      ].filter_map { |key, value| [name, attachment, key, value, bounds[key]] unless value.nil? }
    end

    # How a +present+ key reads: +:attached+ on a strict true or bare key,
    # +:missing+ on an explicit false, nil otherwise.
    #
    # @api private
    # @param bounds [Hash] the raw keys under +filters[<name>]+.
    # @return [Symbol, nil]
    def presence_value(bounds)
      return unless bounds.key?(:present)

      raw = bounds[:present]
      return :attached if Filterable::Togglable.toggled_on?(raw)

      :missing if FALSE_VALUES.include?(raw)
    end

    # Applies one accepted entry onto the scope.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param attachment [Object] the attachment name.
    # @param key [Symbol] the accepted key.
    # @param value [Object] the prepared value.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def apply(sub_scope, attachment, key, value)
      case key
      when :present then presence(sub_scope, attachment, value)
      when :type then content_type(sub_scope, attachment, value)
      when :min_size then minimum_size(sub_scope, attachment, value)
      when :max_size then maximum_size(sub_scope, attachment, value)
      end
    end

    # Keeps attached or unattached records through the generated attachment
    # association.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param attachment [Object] the attachment name.
    # @param value [Symbol] +:attached+ or +:missing+.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def presence(sub_scope, attachment, value)
      association = attachment_association(sub_scope, attachment)
      return sub_scope.where.missing(association) if value == :missing

      attached = sub_scope.where.associated(association)
      collection = sub_scope.klass.reflect_on_attachment(attachment).macro == :has_many_attached
      collection ? attached.distinct : attached
    end

    # Narrows on the blob content type through the generated blob association.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param attachment [Object] the attachment name.
    # @param value [Object] the normalized content type(s).
    # @return [ActiveRecord::Relation] the narrowed relation.
    def content_type(sub_scope, attachment, value)
      Filterable::Target.narrow_equal(sub_scope, blob_target(sub_scope, attachment, :content_type), value)
    end

    # Narrows on the blob byte size, at or above the bound.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param attachment [Object] the attachment name.
    # @param value [Numeric] the parsed bound.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def minimum_size(sub_scope, attachment, value)
      Filterable::Target.narrow(sub_scope, blob_target(sub_scope, attachment, :byte_size)) do |field|
        field.gteq(value)
      end
    end

    # Narrows on the blob byte size, at or below the bound.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param attachment [Object] the attachment name.
    # @param value [Numeric] the parsed bound.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def maximum_size(sub_scope, attachment, value)
      Filterable::Target.narrow(sub_scope, blob_target(sub_scope, attachment, :byte_size)) do |field|
        field.lteq(value)
      end
    end

    # The generated attachment association for a name, singular or plural
    # according to the attachment's macro. Legitimacy comes from ActiveStorage's
    # own reflection registry, never from the shape of an association name — an
    # ordinary association that happens to be called +<name>_attachment+ does
    # not qualify.
    #
    # @api private
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @param attachment [Object] the attachment name.
    # @return [Symbol, nil] the association name, or nil when the model has no
    #   such attachment.
    def attachment_association(scope, attachment)
      klass = scope.klass
      return unless klass.respond_to?(:reflect_on_attachment)

      reflection = klass.reflect_on_attachment(attachment)
      return unless reflection

      reflection.macro == :has_one_attached ? :"#{attachment}_attachment" : :"#{attachment}_attachments"
    end

    # The association-target hash pointing at a blob column.
    #
    # @api private
    # @param scope [ActiveRecord::Relation] the relation being filtered.
    # @param attachment [Object] the attachment name.
    # @param column [Symbol] the blob column.
    # @return [Hash] a target for {Filterable::Target}.
    def blob_target(scope, attachment, column)
      blob = attachment_association(scope, attachment).to_s.sub(/_attachment(s?)\z/, '_blob\1').to_sym
      { blob => column }
    end
  end
end
