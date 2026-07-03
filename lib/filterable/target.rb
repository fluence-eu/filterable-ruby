# frozen_string_literal: true

module Filterable
  # Resolves declared targets: a bare column on the model itself, or a nested
  # one-key hash walking associations to a column on the associated model
  # (+{ account: { bank: :name } }+). Association filtering joins the declared
  # path and merges the condition on the target model, adding DISTINCT when
  # the path crosses a collection. An unresolvable target — unknown or
  # polymorphic association, ambiguous multi-key hash — narrows nothing.
  module Target
    module_function

    # Narrows the scope with an arel condition built on the target's column.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param target [Symbol, String, Hash] the declared target.
    # @yield [field] builds the condition for the resolved column.
    # @yieldparam field [Arel::Attributes::Attribute] the target column.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def narrow(sub_scope, target)
      return sub_scope.where(yield(sub_scope.arel_table[target])) unless target.is_a?(Hash)

      path, column, klass, collection = dissect(sub_scope, target)
      return sub_scope unless klass

      join(sub_scope, path, collection, klass.where(yield(klass.arel_table[column])))
    end

    # Narrows the scope with a hash equality on the target's column, letting
    # ActiveRecord cast the value and expand arrays into IN.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param target [Symbol, String, Hash] the declared target.
    # @param value [Object] the accepted value.
    # @return [ActiveRecord::Relation] the narrowed relation.
    def narrow_equal(sub_scope, target, value)
      return sub_scope.where(target => value) unless target.is_a?(Hash)

      path, column, klass, collection = dissect(sub_scope, target)
      return sub_scope unless klass

      join(sub_scope, path, collection, klass.where(column => value))
    end

    # Splits a nested one-key hash target into its association path and column.
    #
    # @api private
    # @param target [Hash] the declared association target.
    # @return [Array(Array<Symbol>, Object)] the path and the final column —
    #   still a hash when the target is ambiguous.
    def unpack(target)
      path = []
      current = target
      while current.is_a?(Hash) && current.size == 1
        name, current = current.first
        path << name.to_sym
      end
      [path, current]
    end

    # Walks the association path from the model, refusing unknown and
    # polymorphic reflections.
    #
    # @api private
    # @param model [Class] the model the path starts from.
    # @param path [Array<Symbol>] the association names to walk.
    # @return [Array(Class, Boolean)] the target model — nil when the path is
    #   unresolvable — and whether the path crosses a collection.
    def resolve(model, path)
      collection = false
      klass = path.reduce(model) do |current, name|
        reflection = current.reflect_on_association(name)
        break nil if reflection.nil? || reflection.polymorphic?

        collection ||= reflection.collection?
        reflection.klass
      end
      [klass, collection]
    end

    # Unpacks and resolves a hash target in one go.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param target [Hash] the declared association target.
    # @return [Array(Array<Symbol>, Object, Class, Boolean)] path, column,
    #   target model (nil when malformed or unresolvable) and collection flag.
    def dissect(sub_scope, target)
      path, column = unpack(target)
      return [path, column, nil, false] if column.is_a?(Hash) || path.empty?

      klass, collection = resolve(sub_scope.klass, path)
      [path, column, klass, collection]
    end

    # Joins the association path and merges the condition on the target model.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param path [Array<Symbol>] the association names to join.
    # @param collection [Boolean] whether the path crosses a collection.
    # @param condition [ActiveRecord::Relation] the condition on the target model.
    # @return [ActiveRecord::Relation] the joined, narrowed relation.
    def join(sub_scope, path, collection, condition)
      joined = sub_scope.joins(joins_spec(path)).merge(condition)
      collection ? joined.distinct : joined
    end

    # The nested +joins+ argument for an association path.
    #
    # @api private
    # @param path [Array<Symbol>] the association names.
    # @return [Symbol, Hash] e.g. +:account+, or +{ account: :bank }+ when nested.
    def joins_spec(path)
      path.reverse.reduce { |spec, name| { name => spec } }
    end
  end
end
