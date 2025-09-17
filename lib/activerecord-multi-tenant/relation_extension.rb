# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    module ToSqlPatch
      def prepare_update_statement(o)
        if o.key && (has_limit_or_offset_or_orders?(o) || has_join_sources?(o))
          stmt = super
          model = MultiTenant.multi_tenant_model_for_table(MultiTenant::TableNode.table_name(o.relation.left))
          stmt.wheres << MultiTenant::TenantEnforcementClause.new(model.arel_table[model.partition_key])
          stmt
        else
          super
        end
      end

      alias :prepare_delete_statement :prepare_update_statement
    end
  end
end

Arel::Visitors::ToSql.prepend(Arel::Visitors::ToSqlPatch)
