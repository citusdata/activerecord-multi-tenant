require 'active_record'
require_relative "./arel_visitors_depth_first.rb" unless Arel::Visitors.const_defined?(:DepthFirst)

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
      @discovering = false
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

  class ArelTenantVisitor < Arel::Visitors.const_defined?(:DepthFirst) ? Arel::Visitors::DepthFirst : ::MultiTenant::ArelVisitorsDepthFirst
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
        @current_context.visited_handled_relation(o.left.relation) if model.present? && o.left.name.to_s == model.partition_key.to_s
      end
      super(o, *args)
    end

    def visit_MultiTenant_TenantEnforcementClause(o, *)
      @current_context.visited_handled_relation(o.tenant_attribute.relation)
    end

    def visit_MultiTenant_TenantJoinEnforcementClause(o, *)
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

  class BaseTenantEnforcementClause < Arel::Nodes::Node
    attr_reader :tenant_attribute
    def initialize(tenant_attribute)
      @tenant_attribute = tenant_attribute
      @tenant_model = MultiTenant.multi_tenant_model_for_table(tenant_attribute.relation.table_name)
    end

    def to_s; to_sql; end
    def to_str; to_sql; end

    def to_sql(*)
      collector = Arel::Collectors::SQLString.new
      collector = @tenant_model.connection.visitor.accept tenant_arel, collector
      collector.value
    end


  end

  class TenantEnforcementClause < BaseTenantEnforcementClause
    private
    def tenant_arel
      if defined?(Arel::Nodes::Quoted)
        @tenant_attribute.eq(Arel::Nodes::Quoted.new(MultiTenant.current_tenant_id))
      else
        @tenant_attribute.eq(MultiTenant.current_tenant_id)
      end
    end
  end


  class TenantJoinEnforcementClause < BaseTenantEnforcementClause
    attr_reader :table_left
    def initialize(tenant_attribute, table_left)
      super(tenant_attribute)
      @table_left = table_left
      @model_left = MultiTenant.multi_tenant_model_for_table(table_left.table_name)
    end

    private
    def tenant_arel
      @tenant_attribute.eq(@table_left[@model_left.partition_key])
    end
  end


  module TenantValueVisitor
    def visit_MultiTenant_TenantEnforcementClause(o, collector)
      collector << o
    end

    def visit_MultiTenant_TenantJoinEnforcementClause(o, collector)
      collector << o
    end
  end

  module DatabaseStatements
    def join_to_update(update, *args)
      update = super(update, *args)
      model = MultiTenant.multi_tenant_model_for_table(update.ast.relation.table_name)
      if model.present? && !MultiTenant.with_write_only_mode_enabled? && MultiTenant.current_tenant_id.present?
        update.where(MultiTenant::TenantEnforcementClause.new(model.arel_table[model.partition_key]))
      end
      update
    end

    def join_to_delete(delete, *args)
      delete = super(delete, *args)
      model = MultiTenant.multi_tenant_model_for_table(delete.ast.left.table_name)
      if model.present? && !MultiTenant.with_write_only_mode_enabled? && MultiTenant.current_tenant_id.present?
        delete.where(MultiTenant::TenantEnforcementClause.new(model.arel_table[model.partition_key]))
      end
      delete
    end

    def update(arel, name = nil, binds = [])
      model = MultiTenant.multi_tenant_model_for_arel(arel)
      if model.present? && !MultiTenant.with_write_only_mode_enabled? && MultiTenant.current_tenant_id.present?
        arel.where(MultiTenant::TenantEnforcementClause.new(model.arel_table[model.partition_key]))
      end
      super(arel, name, binds)
    end

    def delete(arel, name = nil, binds = [])
      model = MultiTenant.multi_tenant_model_for_arel(arel)
      if model.present? && !MultiTenant.with_write_only_mode_enabled? && MultiTenant.current_tenant_id.present?
        arel.where(MultiTenant::TenantEnforcementClause.new(model.arel_table[model.partition_key]))
      end
      super(arel, name, binds)
    end
  end
end

require 'active_record/connection_adapters/abstract_adapter'
ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(MultiTenant::DatabaseStatements)

Arel::Visitors::ToSql.include(MultiTenant::TenantValueVisitor)

require 'active_record/relation'
module ActiveRecord
  module QueryMethods
    alias :build_arel_orig :build_arel
    def build_arel(*args)
      arel = build_arel_orig(*args)

      if !MultiTenant.with_write_only_mode_enabled?
        visitor = MultiTenant::ArelTenantVisitor.new(arel)

        visitor.contexts.each do |context|
          node = context.arel_node

          context.unhandled_relations.each do |relation|
            model = MultiTenant.multi_tenant_model_for_table(relation.arel_table.table_name)

            if MultiTenant.current_tenant_id
              enforcement_clause = MultiTenant::TenantEnforcementClause.new(relation.arel_table[model.partition_key])
              case node
              when Arel::Nodes::Join #Arel::Nodes::OuterJoin, Arel::Nodes::RightOuterJoin, Arel::Nodes::FullOuterJoin
                node.right.expr = node.right.expr.and(enforcement_clause)
              when Arel::Nodes::SelectCore
                if node.wheres.empty?
                  node.wheres = [enforcement_clause]
                else
                  if node.wheres[0].is_a?(Arel::Nodes::And)
                    node.wheres[0].children << enforcement_clause
                  else
                    node.wheres[0] = enforcement_clause.and(node.wheres[0])
                  end
                end
              else
                raise "UnknownContext"
              end
            end

            if node.is_a?(Arel::Nodes::SelectCore) || node.is_a?(Arel::Nodes::Join)
              if node.is_a?Arel::Nodes::Join
                node_list = [node]
              else
                node_list = node.source.right
              end

              node_list.select{ |n| n.is_a? Arel::Nodes::Join }.each do |node_join|
                if (!node_join.right ||
                    (ActiveRecord::VERSION::MAJOR == 5 &&
                     !node_join.right.expr.right.is_a?(Arel::Attributes::Attribute)))
                  next
                end

                relation_right, relation_left = relations_from_node_join(node_join)

                next unless relation_right && relation_left

                model_right = MultiTenant.multi_tenant_model_for_table(relation_left.table_name)
                model_left = MultiTenant.multi_tenant_model_for_table(relation_right.table_name)
                if model_right && model_left
                  join_enforcement_clause = MultiTenant::TenantJoinEnforcementClause.new(relation_left[model_left.partition_key], relation_right)
                  node_join.right.expr = node_join.right.expr.and(join_enforcement_clause)
                end
              end
            end
          end
        end
      end

      arel
    end

    private
    def relations_from_node_join(node_join)
      if ActiveRecord::VERSION::MAJOR == 5 || node_join.right.expr.is_a?(Arel::Nodes::Equality)
        return node_join.right.expr.right.relation, node_join.right.expr.left.relation
      end

      children = node_join.right.expr.children

      tenant_applied = children.any?(MultiTenant::TenantEnforcementClause) || children.any?(MultiTenant::TenantJoinEnforcementClause)
      if tenant_applied || children.empty?
        return nil, nil
      end

      if children[0].right.respond_to?('relation') && children[0].left.respond_to?('relation')
        return children[0].right.relation, children[0].left.relation
      end

      return nil, nil
    end
  end
end

require 'active_record/base'
module MultiTenantFindBy
  def cached_find_by_statement(key, &block)
    return super unless respond_to?(:scoped_by_tenant?) && scoped_by_tenant?

    key = Array.wrap(key) + [MultiTenant.current_tenant_id.to_s]
    super(key, &block)
  end
end

ActiveRecord::Base.singleton_class.prepend(MultiTenantFindBy)
