# frozen_string_literal: true

module Filterable
  # Resolves declared targets: a bare column on the model itself, or a nested
  # one-key hash walking associations to a column on the associated model
  # (+{ account: { bank: :name } }+). Association filtering joins the declared
  # path and merges the condition on the target model, adding DISTINCT when
  # the path crosses a collection.
  #
  # A polymorphic association — a +delegated_type+ — is crossed by naming the
  # concrete type as the second segment: +{ attachable: { bank: :name } }+
  # joins the concrete table and guards on the +*_type+ column. The hop must
  # open the path and target a column directly on the concrete type.
  #
  # An unresolvable target — unknown association, unguarded polymorphic
  # reflection, unknown concrete type, ambiguous multi-key hash — narrows
  # nothing.
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

      resolution = dissect(sub_scope, target)
      return sub_scope unless resolution

      klass = resolution[:klass]
      apply(sub_scope, resolution, klass.where(yield(klass.arel_table[resolution[:column]])))
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

      resolution = dissect(sub_scope, target)
      return sub_scope unless resolution

      apply(sub_scope, resolution, resolution[:klass].where(resolution[:column] => value))
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

    # Resolves an association path from the model into everything needed to
    # join and narrow — shared by the runtime and the declarations validator so
    # the two cannot drift.
    #
    # @api private
    # @param model [Class] the model the path starts from.
    # @param path [Array<Symbol>] the association names to walk.
    # @return [Hash, nil] +:klass+, +:collection+, +:joins+ and the optional
    #   +:condition+ type guard; nil when the path is unresolvable.
    def resolve(model, path)
      return polymorphic_resolve(model, path) if polymorphic_hop?(model, path)

      collection = false
      klass = path.reduce(model) do |current, name|
        reflection = current.reflect_on_association(name)
        break nil if reflection.nil? || reflection.polymorphic?

        collection ||= reflection.collection?
        reflection.klass
      end
      { klass: klass, collection: collection, joins: joins_spec(path), condition: nil } if klass
    end

    # Whether the path opens with a polymorphic association followed by its
    # concrete type — the only supported polymorphic shape.
    #
    # @api private
    # @param model [Class] the model the path starts from.
    # @param path [Array<Symbol>] the association names to walk.
    # @return [Boolean]
    def polymorphic_hop?(model, path)
      return false unless path.size == 2

      reflection = model.reflect_on_association(path.first)
      !reflection.nil? && reflection.polymorphic?
    end

    # Resolves a polymorphic hop: an arel join onto the concrete type's table,
    # guarded by the polymorphic +*_type+ column.
    #
    # @api private
    # @param model [Class] the model owning the polymorphic association.
    # @param path [Array(Symbol, Symbol)] the association name and concrete type.
    # @return [Hash, nil] the resolution, or nil when the type is not a model.
    def polymorphic_resolve(model, path)
      reflection = model.reflect_on_association(path.first)
      concrete = constantize(path.last)
      return unless concrete

      { klass: concrete, collection: false,
        joins: polymorphic_join(model, reflection, concrete),
        condition: model.arel_table[reflection.foreign_type].eq(concrete.polymorphic_name) }
    end

    # The arel INNER JOIN from the owner onto the concrete type's table.
    #
    # @api private
    # @param model [Class] the model owning the polymorphic association.
    # @param reflection [ActiveRecord::Reflection::AssociationReflection] the polymorphic reflection.
    # @param concrete [Class] the declared concrete type.
    # @return [Array<Arel::Nodes::Join>] the join sources for +joins+.
    def polymorphic_join(model, reflection, concrete)
      owner = model.arel_table
      table = concrete.arel_table
      owner.join(table).on(table[concrete.primary_key].eq(owner[reflection.foreign_key])).join_sources
    end

    # The model class named by a declared concrete-type segment, nil when the
    # name does not resolve to an ActiveRecord model.
    #
    # @api private
    # @param name [Symbol, String] the declared type segment, e.g. +:bank+.
    # @return [Class, nil]
    def constantize(name)
      klass = name.to_s.camelize.safe_constantize
      klass if klass.is_a?(Class) && klass < ActiveRecord::Base
    end

    # Unpacks and resolves a hash target in one go.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param target [Hash] the declared association target.
    # @return [Hash, nil] the resolution with its +:column+, or nil when the
    #   target is malformed or unresolvable.
    def dissect(sub_scope, target)
      path, column = unpack(target)
      return if column.is_a?(Hash) || path.empty?

      resolve(sub_scope.klass, path)&.merge(column: column)
    end

    # Joins the resolution onto the scope and merges the condition on the
    # target model.
    #
    # @api private
    # @param sub_scope [ActiveRecord::Relation] the relation being narrowed.
    # @param resolution [Hash] a {resolve} result.
    # @param condition [ActiveRecord::Relation] the condition on the target model.
    # @return [ActiveRecord::Relation] the joined, narrowed relation.
    def apply(sub_scope, resolution, condition)
      joined = sub_scope.joins(resolution[:joins]).merge(condition)
      joined = joined.where(resolution[:condition]) if resolution[:condition]
      resolution[:collection] ? joined.distinct : joined
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
