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
        if defined?(o.having)
          visit o.having
        else
          visit o.havings
        end
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
    alias :visit_Arel_Nodes_FullOuterJoin :visit_Arel_Nodes_OuterJoin
    alias :visit_Arel_Nodes_RightOuterJoin :visit_Arel_Nodes_OuterJoin

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
    attr_reader :tenant_attribute, :source_attribute
    def initialize(tenant_attribute, source_attribute = nil)
      @tenant_attribute = tenant_attribute
      @source_attribute = source_attribute || MultiTenant.current_tenant_id
    end

    def to_s; to_sql; end
    def to_str; to_sql; end

    def to_sql(*)
      if source_attribute
        tenant_arel.to_sql
      else
        '1=1'
      end
    end

    private

    def tenant_arel
      if defined?(Arel::Nodes::Quoted) && source_attribute.is_a?(String)
        @tenant_attribute.eq(Arel::Nodes::Quoted.new(source_attribute))
      else
        @tenant_attribute.eq(source_attribute)
      end
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

  module SqlWorkarounds
    # Converts SELECT DISTINCT foo, bar to GROUP BY foo, bar
    # to support cross partition queries with eager loaded associations
    def self.convert_distinct_to_group_by(arel)
      ctx = arel.ast.cores.last
      projections = ctx.projections.first
      if ctx.set_quantifier.is_a?(Arel::Nodes::Distinct)
        ctx.set_quantifier = nil
        if projections.is_a?(String)
          return arel.group(ctx.projections.first.gsub(/ AS.*/, ''))
        end
      end

      # Citus does not support cross-partition COUNT(DISTINCT) except
      # For approximations using the HLL extension
      # However, if the query can be converted into a distinct via GROUP BY
      # We can convert it into SELECT COUNT(*) FROM (... GROUP BY ...)
      if projections.is_a?(Arel::Nodes::Count) && projections.distinct
        return arel if MultiTenant.use_hll_counts?
        ctx.projections = projections.expressions
        partition_keys = projections.expressions.map do |e|
          model = MultiTenant.multi_tenant_model_for_table(e.try(:relation).try(:name))
          model.arel_table[model.partition_key] if model
        end.compact
        if partition_keys
          return Arel::Subquery.new(
            arel.group(projections.expressions + partition_keys),
            as: 'countme'
          ).project(Arel.star.count)
        end
      end
      arel
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

      unless MultiTenant.with_write_only_mode_enabled?
        # Get select source to be used in enforcement clause if it is a multi-tenant table
        source_table = arel.source.left
        source_model = MultiTenant.multi_tenant_model_for_table(source_table.table_name)
        source_partition_key = source_model.try(:partition_key)

        visitor = MultiTenant::ArelTenantVisitor.new(arel)
        visitor.contexts.each do |context|
          node = context.arel_node
          relations = if MultiTenant.current_tenant
                        context.unhandled_relations.uniq
                      else
                        relations = context.known_relations.uniq
                      end
          relations.each do |relation|
            model = MultiTenant.multi_tenant_model_for_table(relation.arel_table.table_name)
            if model != source_model && model.partition_key == source_partition_key
              enforcement_clause = MultiTenant::TenantEnforcementClause.new(
                relation.arel_table[model.partition_key],
                source_table[source_partition_key]
              )
            else
              enforcement_clause = MultiTenant::TenantEnforcementClause.new(relation.arel_table[model.partition_key])
            end

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
      return arel if MultiTenant.current_tenant
      MultiTenant::SqlWorkarounds.convert_distinct_to_group_by(arel)
    end
  end
end
