# frozen_string_literal: true

require 'arel/visitors'

# Monkey-patch Arel::Visitors::ToSql to support Arel::Subquery
module Arel
  module Visitors
    class ToSql < Arel::Visitors::Reduce
      def visit_Arel_Subquery(o, collector)
        collector << '('
        collector << case o.data_source
        when String
          o.data_source
        when Arel::SelectManager
          o.data_source.to_sql
        else
          o.data_source.to_s
        end
        collector << ") #{quote_table_name o.name}"
      end
    end
  end
end
