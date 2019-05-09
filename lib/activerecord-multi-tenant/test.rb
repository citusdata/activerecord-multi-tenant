
  MultiTenant.with(practice) do
    Client.first
  end



            if node.is_a? Arel::Nodes::SelectCore
              node.source.right.select{ |n| n.is_a? Arel::Nodes::Join }.each do |node_join|
                table_left = node_join.right.expr.right.relation
                table_right = node_join.right.expr.left.relation
                model_left = MultiTenant.multi_tenant_model_for_table(table_left)
                if table_left != table_right && model_left
                  join_enforcement_clause = MultiTenant::TenantJoinEnforcementClause.new(table_right.arel_table[model.partition_key], table_left.arel_table)
                  node_join.right.expr = node_join.right.expr.and(join_enforcement_clause)
                end
              end
            end
          end
        end
      end







-- new


            if node.is_a? Arel::Nodes::SelectCore
              node.source.right.select{ |n| n.is_a? Arel::Nodes::Join }.each do |node_join|
                arel_on_left = node_join.right.expr.left
                arel_on_right = node_join.right.expr.right

                if arel_on_left.is_a? Arel::Attributes::Attribute
                  model_left = MultiTenant.multi_tenant_model_for_table(arel_on_left.relation)

                  if model_left
                    join_enforcement_clause = MultiTenant::TenantJoinEnforcementClause.new(arel_on_right.relation.arel_table[model.partition_key], arel_on_left.relation)
                    node_join.right.expr = node_join.right.expr.and(join_enforcement_clause)
                  end
                end
