require 'active_record'

module MultiTenant
  class ArelTenantVisitor < Arel::Visitors::DepthFirst
    def initialize(arel)
      super(Proc.new {})
      @tenant_relations = []
      @existing_tenant_relations = []
      @outer_joins_by_table_name = {}

      accept(arel.ast)
    end

    def tenant_relations
      @tenant_relations.uniq
    end

    def existing_tenant_relations
      @existing_tenant_relations.uniq
    end

    def outer_joins_by_table_name
      @outer_joins_by_table_name
    end

    def visit_Arel_Table(table, _collector = nil)
      @tenant_relations << table if tenant_relation?(table.table_name)
    end

    def visit_Arel_Nodes_TableAlias(table_alias, _collector = nil)
      @tenant_relations << table_alias if tenant_relation?(table_alias.table_name)
    end

    def visit_Arel_Nodes_Equality(o, _collector = nil)
      if o.left.is_a?(Arel::Attributes::Attribute)
        table_name = o.left.relation.table_name
        model = MultiTenant.multi_tenant_model_for_table(table_name)
        @existing_tenant_relations << o.left.relation if model.present? && o.left.name == model.partition_key
      end
    end

    def visit_Arel_Nodes_OuterJoin(o, collector = nil)
      if o.left.is_a?(Arel::Nodes::TableAlias) || o.left.is_a?(Arel::Table)
        @outer_joins_by_table_name[o.left.name] = o
      end
      visit o.left
      visit o.right
    end
    alias :visit_Arel_Nodes_FullOuterJoin :visit_Arel_Nodes_OuterJoin
    alias :visit_Arel_Nodes_RightOuterJoin :visit_Arel_Nodes_OuterJoin

    private

    def tenant_relation?(table_name)
      MultiTenant.multi_tenant_model_for_table(table_name).present?
    end
  end
end

require 'active_record/relation'
module ActiveRecord
  module QueryMethods
    alias :build_arel_orig :build_arel
    def build_arel
      arel = build_arel_orig

      if MultiTenant.current_tenant_id && !MultiTenant.with_write_only_mode_enabled?
        visitor = MultiTenant::ArelTenantVisitor.new(arel)
        relations_needing_tenant_id = visitor.tenant_relations
        known_relations = visitor.existing_tenant_relations
        relations_needing_tenant_id.each do |relation|
          model = MultiTenant.multi_tenant_model_for_table(relation.table_name)
          next unless model.present?
          next if known_relations.map(&:name).include?(relation.name)

          top_level_tenant_relation = known_relations.reject { |r| visitor.outer_joins_by_table_name.key?(r.name) }.first
          tenant_value = if top_level_tenant_relation.present?
                           known_model = MultiTenant.multi_tenant_model_for_table(top_level_tenant_relation.table_name)
                           top_level_tenant_relation[known_model.partition_key]
                         else
                           MultiTenant.current_tenant_id
                         end

          known_relations << relation

          outer_join = visitor.outer_joins_by_table_name[relation.name]
          if outer_join
            outer_join.right.expr = Arel::Nodes::And.new([outer_join.right.expr, relation[model.partition_key].eq(tenant_value)])
          else
            ctx = arel.ast.cores.last
            if ctx.wheres.size == 1
              ctx.wheres = [Arel::Nodes::And.new([ctx.wheres.first, relation[model.partition_key].eq(tenant_value)])]
            else
              arel = arel.where(relation[model.partition_key].eq(tenant_value))
            end
          end
        end
      end

      arel
    end
  end
end
