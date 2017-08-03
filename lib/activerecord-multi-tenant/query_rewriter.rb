require 'active_record'

module MultiTenant
  class ArelTenantVisitor < Arel::Visitors::DepthFirst
    def initialize(arel)
      super(Proc.new {})
      @tenant_relations = {}
      @existing_tenant_relations = {}
      @outer_joins_by_table_name = {}
      @statement_node_id = nil

      accept(arel.ast)
    end

    def tenant_relations
      @tenant_relations
    end

    def existing_tenant_relations
      @existing_tenant_relations
    end

    def outer_joins_by_table_name
      @outer_joins_by_table_name
    end

    def visit_Arel_Table(o, _collector = nil)
      @tenant_relations[@statement_node_id] ||= []
      @tenant_relations[@statement_node_id] << o if tenant_relation?(o.table_name)
    end
    alias :visit_Arel_Nodes_TableAlias :visit_Arel_Table

    def visit_Arel_Nodes_SelectStatement(o, _collector = nil)
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

    def visit_Arel_Nodes_OuterJoin(o, collector = nil)
      if o.left.is_a?(Arel::Nodes::TableAlias) || o.left.is_a?(Arel::Table)
        @outer_joins_by_table_name[@statement_node_id] ||= {}
        @outer_joins_by_table_name[@statement_node_id][o.left.name] = o
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

  # We use a proxy object in the arel tree instead of the actual value to avoid
  # the tenant value being cached by the Rails statement cache. Whilst it would
  # also be possible to use bind parameters for a similar benefit, they interact
  # oddly with the statement cache in Rails versions before 5.0.
  class TenantValueParam < Arel::Nodes::Node
    def to_s
      MultiTenant.current_tenant_id.to_s
    end

    def to_str; to_s; end
    def to_sql(*args); to_s; end
  end

  module TenantValueVisitor
    if ActiveRecord::VERSION::MAJOR > 4 || (ActiveRecord::VERSION::MAJOR == 4 && ActiveRecord::VERSION::MINOR >= 2)
      def visit_MultiTenant_TenantValueParam(o, collector)
        collector << o
      end
    else
      def visit_MultiTenant_TenantValueParam(o, a = nil)
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
          outer_joins_by_table_name = visitor.outer_joins_by_table_name[statement_node_id] || {}

          relations.each do |relation|
            model = MultiTenant.multi_tenant_model_for_table(relation.table_name)
            next unless model.present?
            next if known_relations.map(&:name).include?(relation.name)

            tenant_relation = known_relations.reject { |r| outer_joins_by_table_name.key?(r.name) }.first
            tenant_value = if tenant_relation.present?
                             known_model = MultiTenant.multi_tenant_model_for_table(tenant_relation.table_name)
                             tenant_relation[known_model.partition_key]
                           elsif ActiveRecord::VERSION::MAJOR >= 4
                             MultiTenant::TenantValueParam.new # Prevents caching issues, see above
                           else
                             MultiTenant.current_tenant_id
                           end

            known_relations << relation

            outer_join = outer_joins_by_table_name[relation.name]
            if outer_join
              outer_join.right.expr = outer_join.right.expr.and(relation[model.partition_key].eq(tenant_value))
            else
              ctx = arel.ast.cores.last
              if ctx.wheres.size == 1
                ctx.wheres = [relation[model.partition_key].eq(tenant_value).and(ctx.wheres.first)]
              else
                arel = arel.where(relation[model.partition_key].eq(tenant_value))
              end
            end
          end
        end
      end

      arel
    end
  end
end
