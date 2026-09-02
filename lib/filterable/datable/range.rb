# frozen_string_literal: true

module Filterable
  module Datable
    # Keeps rows whose datable attribute falls within an inclusive range.
    # Reads +filters[<attribute>][from]+ and +filters[<attribute>][to]+, applied
    # only when both bounds are present and parseable.
    module Range
      module_function

      # Narrows the scope to rows within each declared attribute's inclusive +from+/+to+ range.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [ActiveRecord::Relation] the narrowed relation.
      def call(params, scope)
        entries = Filterable::Datable.accepted(params, scope, :from, :to)
        entries.reduce(scope) do |sub_scope, (_name, target, bounds, parsed)|
          floor = floor_for(sub_scope, target, bounds[:from], parsed[:from])
          Filterable::Target.narrow(sub_scope, target) do |field|
            field.gteq(floor).and(ceiling_for(field, sub_scope, target, bounds[:to], parsed[:to]))
          end
        end
      end

      # The inclusive floor: the day's first instant when +from+ names a whole day,
      # the parsed bound otherwise.
      #
      # @api private
      # @return [Date, Time]
      def floor_for(scope, target, raw, parsed)
        return parsed unless Filterable::Datable.whole_day?(scope, target, raw)

        Filterable::Datable.day_start(raw)
      end

      # The inclusive ceiling: a whole day is admitted up to the next midnight,
      # excluded, so every instant of the day it names is kept.
      #
      # @api private
      # @return [Arel::Nodes::Node]
      def ceiling_for(field, scope, target, raw, parsed)
        return field.lteq(parsed) unless Filterable::Datable.whole_day?(scope, target, raw)

        field.lt(Filterable::Datable.day_end(raw))
      end

      # The bounds {call} would apply, keyed by public name, with their raw values.
      #
      # @api private
      # @param params [Hash, ActionController::Parameters] the nested +filters+ params.
      # @param scope [ActiveRecord::Relation] the relation being filtered.
      # @return [Hash{Symbol, String => Hash}] public name => accepted +from+/+to+ bounds.
      def applied(params, scope)
        entries = Filterable::Datable.accepted(params, scope, :from, :to)
        entries.each_with_object({}) do |(name, _column, bounds, _parsed), report|
          report[name] = bounds.slice(:from, :to)
        end
      end
    end
  end
end
