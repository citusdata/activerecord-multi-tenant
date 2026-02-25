# frozen_string_literal: true

module Arel
  module ActiveRecordRelationExtension
    # Overrides the delete_all method to include tenant scoping
    def delete_all
      # Call the original delete_all method if the current tenant is identified by an ID
      return super if MultiTenant.current_tenant_is_id? || MultiTenant.current_tenant.nil? || primary_key.nil?

      stmt = Arel::DeleteManager.new.from(table)
      stmt.wheres = [generate_in_condition_subquery]

      # Execute the delete statement using the connection and return the result
      klass.connection.delete(stmt, "#{klass} Delete All").tap { reset }
    end

    # Overrides the update_all method to include tenant scoping
    def update_all(updates)
      # Call the original update_all method if the current tenant is identified by an ID
      return super if MultiTenant.current_tenant_is_id? || MultiTenant.current_tenant.nil?

      stmt = Arel::UpdateManager.new
      stmt.table(table)

      # Handle updates differently based on whether it's a hash with Arel nodes or regular values
      if updates.is_a?(Hash) && updates.values.any? { |value| value.is_a?(Arel::Nodes::Node) }
        # For hash with Arel nodes, build assignments directly
        assignments = updates.map do |column, value|
          if value.is_a?(Arel::Nodes::Node)
            [table[column], value]
          else
            [table[column], Arel::Nodes.build_quoted(value, table[column])]
          end
        end
        stmt.set assignments
      else
        # For regular updates, use sanitize_sql_for_assignment
        stmt.set Arel.sql(klass.send(:sanitize_sql_for_assignment, updates))
      end

      stmt.wheres = [generate_in_condition_subquery]

      klass.connection.update(stmt, "#{klass} Update All").tap { reset }
    end

    private

    # The generate_in_condition_subquery method generates a subquery that selects
    # records associated with the current tenant.
    def generate_in_condition_subquery
      # Get the tenant key and tenant ID based on the current tenant
      tenant_key = MultiTenant.partition_key(MultiTenant.current_tenant_class)
      tenant_id = MultiTenant.current_tenant_id

      # Build an Arel query
      arel = if eager_loading?
               apply_join_dependency.arel
             elsif ActiveRecord.gem_version >= Gem::Version.create('7.2.0')
               build_arel(klass.connection)
             else
               build_arel
             end

      arel.source.left = table

      # If the tenant ID is present and the tenant key is a column in the model,
      # add a condition to only include records where the tenant key equals the tenant ID
      if tenant_id && klass.column_names.include?(tenant_key)
        tenant_condition = table[tenant_key].eq(tenant_id)
        unless arel.constraints.any? { |node| node.to_sql.include?(tenant_condition.to_sql) }
          arel = arel.where(tenant_condition)
        end
      end

      # Clone the query, clear its projections, and set its projection to the primary key of the table
      subquery = arel.clone
      subquery.projections.clear
      subquery = subquery.project(table[primary_key])

      # Create an IN condition node with the primary key of the table and the subquery
      Arel::Nodes::In.new(table[primary_key], subquery.ast)
    end
  end
end

# Patch ActiveRecord::Relation with the extension module
ActiveRecord::Relation.prepend(Arel::ActiveRecordRelationExtension)
