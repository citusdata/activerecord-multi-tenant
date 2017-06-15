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
      @tenant_relations << table if tenant_relation?(table.table_name)
    end

    def visit_Arel_Nodes_TableAlias(table_alias, _collector = nil)
      @tenant_relations << table_alias if tenant_relation?(table_alias.table_name)
    end

    private

    def tenant_relation?(table_name)
      MultiTenant.multi_tenant_model_for_table(table_name).present?
    end
  end
end

module ActiveRecord
  module QueryMethods
    alias :build_arel_orig :build_arel
    def build_arel
      arel = build_arel_orig

      if MultiTenant.current_tenant_id && !MultiTenant.with_write_only_mode_enabled?
        relations_needing_tenant_id = MultiTenant::ArelTenantVisitor.new(arel).tenant_relations
        arel = relations_needing_tenant_id.reduce(arel) do |arel, relation|
          model = MultiTenant.multi_tenant_model_for_table(relation.table_name)
          next arel unless model.present?
          arel.where(relation[model.partition_key].eq(MultiTenant.current_tenant_id))
        end
      end

      arel
    end
  end
end
