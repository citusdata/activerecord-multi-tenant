require 'active_record'

class TTTenantVisitor < Arel::Visitors::DepthFirst
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
    model = table.name.classify.safe_constantize
    model && model.respond_to?(:scoped_by_tenant?) && model.scoped_by_tenant?
  end
end


require 'active_record/relation'
require 'active_record/relation/query_methods'
module ActiveRecord
  module QueryMethods
    alias :build_arel_orig :build_arel
    def build_arel
      arel = build_arel_orig

      if MultiTenant.current_tenant_id && !MultiTenant.with_write_only_mode_enabled?
        relations_needing_tenant_id = TTTenantVisitor.new(arel).tenant_relations
        arel = relations_needing_tenant_id.reduce(arel) do |arel, relation|
          arel.where(relation[self.partition_key].eq(MultiTenant.current_tenant_id))
        end
      end

      arel
    end
  end
end
