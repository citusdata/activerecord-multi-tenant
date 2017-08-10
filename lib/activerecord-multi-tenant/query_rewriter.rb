require 'active_record'

module MultiTenant
  class ArelTenantVisitor < Arel::Visitors::DepthFirst
    def initialize(arel)
      super(Proc.new {})
      @tenant_relations = {}
      @existing_tenant_relations = {}
      @joins_by_table_name = {}
      @statement_node_id = nil

      accept(arel.ast)
    end

    def tenant_relations
      @tenant_relations
    end

    def existing_tenant_relations
      @existing_tenant_relations
    end

    def joins_by_table_name
      @joins_by_table_name
    end

    def visit_Arel_Table(o, _collector = nil)
      @tenant_relations[@statement_node_id] ||= []
      @tenant_relations[@statement_node_id] << o if tenant_relation?(o.table_name)
    end
    alias :visit_Arel_Nodes_TableAlias :visit_Arel_Table

    def visit_Arel_Nodes_SelectStatement(o, _collector = nil)
      return if @statement_node_id
      @statement_node_id = o.object_id
      visit o.cores
      visit o.orders
      visit o.limit
      visit o.lock
      visit o.offset
    end

    def visit_Arel_Nodes_Equality(o, _collector = nil)
      if o.left.is_a?(Arel::Attributes::Attribute)
        table_name = o.left.relation.table_name
        model = MultiTenant.multi_tenant_model_for_table(table_name)
        @existing_tenant_relations[@statement_node_id] ||= []
        @existing_tenant_relations[@statement_node_id] << o.left.relation if model.present? && o.left.name == model.partition_key
      end
    end

    def visit_join(o, collector = nil)
      if o.left.is_a?(Arel::Nodes::TableAlias) || o.left.is_a?(Arel::Table)
        @joins_by_table_name[@statement_node_id] ||= {}
        @joins_by_table_name[@statement_node_id][o.left.name] = o
      end
      visit o.left
      visit o.right
    end
    alias :visit_Arel_Nodes_OuterJoin :visit_join
    alias :visit_Arel_Nodes_FullOuterJoin :visit_join
    alias :visit_Arel_Nodes_RightOuterJoin :visit_join
    alias :visit_Arel_Nodes_InnerJoin :visit_join

    private

    def tenant_relation?(table_name)
      MultiTenant.multi_tenant_model_for_table(table_name).present?
    end
  end

  class TenantEnforcementClause < Arel::Nodes::Node
    def initialize(tenant_attribute)
      @tenant_attribute = tenant_attribute
    end

    def to_s; to_sql; end
    def to_str; to_sql; end

    def to_sql(*)
      if MultiTenant.current_tenant_id
        tenant_arel.to_sql
      else
        '1=1'
      end
    end

    private

    def tenant_arel
      @tenant_attribute.eq(MultiTenant.current_tenant_id)
    end
  end

  module TenantValueVisitor
    if ActiveRecord::VERSION::MAJOR > 4 || (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR >= 2)
      def visit_MultiTenant_TenantEnforcementClause(o, collector)
        collector << o
      end
    else
      def visit_MultiTenant_TenantEnforcementClause(o, a = nil)
        o
      end
    end
  end
end

Arel::Visitors::ToSql.include(MultiTenant::TenantValueVisitor)

require 'active_record/relation'
module ActiveRecord
  module QueryMethods
    alias :build_arel_orig :build_arel
    def build_arel
      arel = build_arel_orig

      if MultiTenant.current_tenant_id && !MultiTenant.with_write_only_mode_enabled?
        visitor = MultiTenant::ArelTenantVisitor.new(arel)
        visitor.tenant_relations.each do |statement_node_id, relations|
          # Process every level of the statement separately, so we don't mix subselects
          known_relations = visitor.existing_tenant_relations[statement_node_id] || []
          joins_by_table_name = visitor.joins_by_table_name[statement_node_id] || {}

          relations.each do |relation|
            model = MultiTenant.multi_tenant_model_for_table(relation.table_name)
            next unless model.present?

            next if known_relations.map(&:name).include?(relation.name)
            known_relations << relation

            join = joins_by_table_name[relation.name]
            if join
              joined_relation = join.right.expr.right.relation
              joined_relation = join.right.expr.left.relation if joined_relation.table_name == relation.table_name
              joined_model = MultiTenant.multi_tenant_model_for_table(joined_relation.table_name)
              tenant_cond = relation[model.partition_key].eq(joined_relation[joined_model.partition_key])
              join.right.expr = join.right.expr.and(tenant_cond)
            else
              ctx = arel.ast.cores.last
              enforcement_clause = MultiTenant::TenantEnforcementClause.new(relation[model.partition_key])
              if ctx.wheres.size == 1
                ctx.wheres = [enforcement_clause.and(ctx.wheres.first)]
              else
                arel = arel.where(enforcement_clause)
              end
            end
          end
        end
      end

      arel
    end
  end
end
