module Arel
  module ActiveRecordRelationExtension
    def delete_all(conditions = nil)
      tenant_id = MultiTenant.current_tenant_id
      tenant_key = MultiTenant.partition_key(MultiTenant.current_tenant_class)

      arel = eager_loading? ? apply_join_dependency.arel : build_arel
      arel.source.left = table

      group_values_arel_columns = arel_columns(group_values.uniq)
      having_clause_ast = having_clause.ast unless having_clause.empty?
      stmt = arel.compile_delete(table[primary_key], having_clause_ast, group_values_arel_columns)

      if tenant_id
        tenant_condition = table[tenant_key.downcase].eq(tenant_id)
        account_condition = table["account_id"].eq(tenant_id)
        conditions = Arel::Nodes::And.new([tenant_condition, conditions].compact)
        puts "conditions: #{conditions.to_sql}"
        puts "tenant_id: #{tenant_id}"
      end

      puts "stmt klass: #{stmt.class}"

      if conditions
        stmt.where(conditions)
      end

      puts "stmtt: #{stmt.to_sql}"
      klass.connection.delete(stmt, "#{klass} Delete All").tap { reset }
    end
  end
end

# Patch ActiveRecord::Relation with the extension module
ActiveRecord::Relation.prepend(Arel::ActiveRecordRelationExtension)
