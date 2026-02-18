# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    module ToSqlPatch
      def prepare_update_statement(object)
        if object.key && (has_limit_or_offset_or_orders?(object) || has_join_sources?(object))
          stmt = super

          model = MultiTenant.multi_tenant_model_for_table(MultiTenant::TableNode.table_name(object.relation.left))
          if model.present? && !MultiTenant.with_write_only_mode_enabled? && MultiTenant.current_tenant_id.present?
            stmt.wheres << MultiTenant::TenantEnforcementClause.new(model.arel_table[model.partition_key])
          end

          stmt
        else
          super
        end
      end

      alias prepare_delete_statement prepare_update_statement
    end
  end
end

Arel::Visitors::ToSql.prepend(Arel::Visitors::ToSqlPatch)
