require 'active_record'

module MultiTenant
  class ArelTenantVisitor < Arel::Visitors::DepthFirst
    def initialize(arel)
      super(Proc.new {})
      @tenant_relations = []

      accept(arel.ast)
    end

    def tenant_relations
      @tenant_relations.uniq
    end

    def visit_Arel_Table(table, _collector = nil)
      @tenant_relations << table if tenant_relation?(table)
    end

    def visit_Arel_Nodes_TableAlias(table_alias, _collector = nil)
      @tenant_relations << table_alias if tenant_relation?(table_alias.left)
    end

    private

    def tenant_relation?(table)
      MultiTenant.multi_tenant_model_for_table(table.name).present?
    end
  end
end

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseStatements
      alias :to_sql_orig :to_sql
      # Converts an arel AST to SQL
      def to_sql(arel, binds = [])
        if MultiTenant.current_tenant_id && !MultiTenant.with_write_only_mode_enabled? &&
          [Arel::SelectManager, Arel::UpdateManager, Arel::DeleteManager, ActiveRecord::Relation].include?(arel.class)
          relations_needing_tenant_id = MultiTenant::ArelTenantVisitor.new(arel).tenant_relations
          arel = relations_needing_tenant_id.reduce(arel) do |arel, relation|
            model = MultiTenant.multi_tenant_model_for_table(relation.table_name)
            next arel unless model.present?
            arel.where(relation[model.partition_key].eq(MultiTenant.current_tenant_id))
          end
        end
        to_sql_orig(arel, binds)
      end
    end
  end
end
