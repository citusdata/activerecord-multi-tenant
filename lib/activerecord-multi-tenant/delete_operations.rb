# frozen_string_literal: true

module Arel
  module ActiveRecordRelationExtension
    # Overrides the delete_all method to include tenant scoping
    def delete_all
      # Call the original delete_all method if the current tenant is identified by an ID
      return super if MultiTenant.current_tenant_is_id? || MultiTenant.current_tenant.nil?

      tenant_key = MultiTenant.partition_key(MultiTenant.current_tenant_class)
      tenant_id = MultiTenant.current_tenant_id
      arel = eager_loading? ? apply_join_dependency.arel : build_arel
      arel.source.left = table

      if tenant_id && klass.column_names.include?(tenant_key)
        # Check if the tenant key is present in the model's column names
        tenant_condition = table[tenant_key].eq(tenant_id)
        # Add the tenant condition to the arel query if it is not already present
        unless arel.constraints.any? { |node| node.to_sql.include?(tenant_condition.to_sql) }
          arel = arel.where(tenant_condition)
        end
      end

      subquery = arel.clone
      subquery.projections.clear
      subquery = subquery.project(table[primary_key])
      in_condition = Arel::Nodes::In.new(table[primary_key], subquery.ast)
      stmt = Arel::DeleteManager.new.from(table)
      stmt.wheres = [in_condition]

      # Execute the delete statement using the connection and return the result
      klass.connection.delete(stmt, "#{klass} Delete All").tap { reset }
    end
  end
end

# Patch ActiveRecord::Relation with the extension module
ActiveRecord::Relation.prepend(Arel::ActiveRecordRelationExtension)
