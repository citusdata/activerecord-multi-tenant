require 'active_record'

module MultiTenant
  class Table
    attr_reader :arel_table

    def initialize(arel_table)
      @arel_table = arel_table
    end

    def eql?(rhs)
      self.class == rhs.class &&
        equality_fields.eql?(rhs.equality_fields)
    end

    def hash
      equality_fields.hash
    end

    protected

    def equality_fields
      [arel_table.name, arel_table.table_alias]
    end
  end

  class Context
    attr_reader :arel_node, :known_relations, :handled_relations

    def initialize(arel_node)
      @arel_node = arel_node
      @known_relations = []
      @handled_relations = []
    end

    def discover_relations
      old_discovering = @discovering
      @discovering = true
      yield
      @discovering = old_discovering
    end

    def visited_relation(relation)
      return unless @discovering
      @known_relations << Table.new(relation)
    end

    def visited_handled_relation(relation)
      @handled_relations << Table.new(relation)
    end

    def unhandled_relations
      known_relations.uniq - handled_relations
    end
  end

  class ArelTenantVisitor < Arel::Visitors::DepthFirst
    def initialize(arel)
      super(Proc.new {})
      @statement_node_id = nil

      @contexts = []
      @current_context = nil
      accept(arel.ast)
    end

    attr_reader :contexts

    def visit_Arel_Attributes_Attribute(*args)
      return if @current_context.nil?
      super(*args)
    end

    def visit_Arel_Nodes_Equality(o, *args)
      if o.left.is_a?(Arel::Attributes::Attribute)
        table_name = o.left.relation.table_name
        model = MultiTenant.multi_tenant_model_for_table(table_name)
        @current_context.visited_handled_relation(o.left.relation) if model.present? && o.left.name == model.partition_key
      end
      super(o, *args)
    end

    def visit_MultiTenant_TenantEnforcementClause(o, *)
      @current_context.visited_handled_relation(o.tenant_attribute.relation)
    end

    def visit_Arel_Table(o, _collector = nil)
      @current_context.visited_relation(o) if tenant_relation?(o.table_name)
    end
    alias :visit_Arel_Nodes_TableAlias :visit_Arel_Table

    def visit_Arel_Nodes_SelectCore(o, *args)
      nest_context(o) do
        @current_context.discover_relations do
          visit o.source
        end
        visit o.wheres
        visit o.groups
        visit o.windows
        visit o.having
      end
    end

    def visit_Arel_Nodes_OuterJoin(o, collector = nil)
      nest_context(o) do
        @current_context.discover_relations do
          visit o.left
          visit o.right
        end
      end
    end
    alias :visit_Arel_Nodes_OuterJoin :visit_join
    alias :visit_Arel_Nodes_FullOuterJoin :visit_join
    alias :visit_Arel_Nodes_RightOuterJoin :visit_join
    alias :visit_Arel_Nodes_InnerJoin :visit_join

    private

    def tenant_relation?(table_name)
      MultiTenant.multi_tenant_model_for_table(table_name).present?
    end

    DISPATCH = Hash.new do |hash, klass|
      hash[klass] = "visit_#{(klass.name || '').gsub('::', '_')}"
    end

    def dispatch
      DISPATCH
    end

    def get_dispatch_cache
      dispatch
    end

    def nest_context(o)
      old_context = @current_context
      @current_context = Context.new(o)
      @contexts << @current_context

      yield

      @current_context = old_context
    end
  end

  class TenantEnforcementClause < Arel::Nodes::Node
    attr_reader :tenant_attribute
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
        visitor.contexts.each do |context|
          node = context.arel_node
          context.unhandled_relations.each do |relation|
            model = MultiTenant.multi_tenant_model_for_table(relation.arel_table.table_name)
            enforcement_clause = MultiTenant::TenantEnforcementClause.new(relation.arel_table[model.partition_key])

            case node
            when Arel::Nodes::Join #Arel::Nodes::OuterJoin, Arel::Nodes::RightOuterJoin, Arel::Nodes::FullOuterJoin
              node.right.expr = node.right.expr.and(enforcement_clause)
            when Arel::Nodes::SelectCore
              if node.wheres.empty?
                node.wheres = [enforcement_clause]
              else
                node.wheres[0] = enforcement_clause.and(node.wheres[0])
              end
            else
              raise "UnknownContext"
            end
          end
        end
      end

      arel
    end
  end
end
