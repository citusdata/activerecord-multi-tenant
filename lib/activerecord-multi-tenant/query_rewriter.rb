# frozen_string_literal: true

require 'active_record'
require_relative 'arel_visitors_depth_first' unless Arel::Visitors.const_defined?(:DepthFirst)

# Iterates AST and adds tenant enforcement clauses to all relations
module MultiTenant
  class Table
    attr_reader :arel_table

    def initialize(arel_table)
      @arel_table = arel_table
    end

    def eql?(other)
      self.class == other.class &&
        equality_fields.eql?(other.equality_fields)
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

  class ArelTenantVisitor < if Arel::Visitors.const_defined?(:DepthFirst)
                              Arel::Visitors::DepthFirst
                            else
                              ::MultiTenant::ArelVisitorsDepthFirst
                            end
    def initialize(arel)
      super(proc {})
      @statement_node_id = nil

      @contexts = []
      @current_context = nil
      accept(arel.ast)
    end

    attr_reader :contexts

    # rubocop:disable Naming/MethodName
    def visit_Arel_Attributes_Attribute(*args)
      return if @current_context.nil?

      super
    end

    def visit_Arel_Nodes_Equality(obj, *args)
      if obj.left.is_a?(Arel::Attributes::Attribute)
        table_name = MultiTenant::TableNode.table_name(obj.left.relation)
        model = MultiTenant.multi_tenant_model_for_table(table_name)
        if model.present? && obj.left.name.to_s == model.partition_key.to_s
          @current_context.visited_handled_relation(obj.left.relation)
        end
      end
      super
    end

    def visit_MultiTenant_TenantEnforcementClause(obj, *)
      @current_context.visited_handled_relation(obj.tenant_attribute.relation)
    end

    def visit_MultiTenant_TenantJoinEnforcementClause(obj, *)
      @current_context.visited_handled_relation(obj.tenant_attribute.relation)
    end

    def visit_Arel_Table(obj, _collector = nil)
      @current_context.visited_relation(obj) if tenant_relation?(MultiTenant::TableNode.table_name(obj))
    end

    alias visit_Arel_Nodes_TableAlias visit_Arel_Table

    def visit_Arel_Nodes_SelectCore(obj, *_args)
      nest_context(obj) do
        @current_context.discover_relations do
          visit obj.source
        end
        visit obj.wheres
        visit obj.groups
        visit obj.windows
        if defined?(obj.having)
          visit obj.having
        else
          visit obj.havings
        end
      end
    end

    # rubocop:enable Naming/MethodName

    # rubocop:disable Naming/MethodName
    def visit_Arel_Nodes_OuterJoin(obj, _collector = nil)
      nest_context(obj) do
        @current_context.discover_relations do
          visit obj.left
          visit obj.right
        end
      end
    end

    # rubocop:enable Naming/MethodName

    alias visit_Arel_Nodes_FullOuterJoin visit_Arel_Nodes_OuterJoin
    alias visit_Arel_Nodes_RightOuterJoin visit_Arel_Nodes_OuterJoin

    alias visit_ActiveModel_Attribute terminal

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

    # rubocop:disable Naming/AccessorMethodName
    def get_dispatch_cache
      dispatch
    end

    # rubocop:enable Naming/AccessorMethodName

    def nest_context(obj)
      old_context = @current_context
      @current_context = Context.new(obj)
      @contexts << @current_context

      yield

      @current_context = old_context
    end
  end

  class BaseTenantEnforcementClause < Arel::Nodes::Node
    attr_reader :tenant_attribute

    def initialize(tenant_attribute)
      super()
      @tenant_attribute = tenant_attribute
      @tenant_model = MultiTenant.multi_tenant_model_for_table(
        MultiTenant::TableNode.table_name(tenant_attribute.relation)
      )
    end

    def to_s
      to_sql
    end

    def to_str
      to_sql
    end

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
      @model_left = MultiTenant.multi_tenant_model_for_table(MultiTenant::TableNode.table_name(table_left))
    end

    private

    def tenant_arel
      @tenant_attribute.eq(@table_left[@model_left.partition_key])
    end
  end

  module TenantValueVisitor
    # rubocop:disable Naming/MethodName
    def visit_MultiTenant_TenantEnforcementClause(obj, collector)
      collector << obj
    end

    def visit_MultiTenant_TenantJoinEnforcementClause(obj, collector)
      collector << obj
    end

    # rubocop:enable Naming/MethodName
  end

  module DatabaseStatements
    def join_to_update(update, *args)
      update = super
      model = MultiTenant.multi_tenant_model_for_table(MultiTenant::TableNode.table_name(update.ast.relation))
      if model.present? && !MultiTenant.with_write_only_mode_enabled? && MultiTenant.current_tenant_id.present?
        update.where(MultiTenant::TenantEnforcementClause.new(model.arel_table[model.partition_key]))
      end
      update
    end

    def join_to_delete(delete, *args)
      delete = super
      model = MultiTenant.multi_tenant_model_for_table(MultiTenant::TableNode.table_name(delete.ast.left))
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
      super
    end

    def delete(arel, name = nil, binds = [])
      model = MultiTenant.multi_tenant_model_for_arel(arel)
      if model.present? && !MultiTenant.with_write_only_mode_enabled? && MultiTenant.current_tenant_id.present?
        arel.where(MultiTenant::TenantEnforcementClause.new(model.arel_table[model.partition_key]))
      end
      super
    end
  end
end

require 'active_record/connection_adapters/abstract_adapter'
ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(MultiTenant::DatabaseStatements)

Arel::Visitors::ToSql.include(MultiTenant::TenantValueVisitor)

module MultiTenant
  module QueryMethodsExtensions
    def build_arel(*)
      arel = super

      unless MultiTenant.with_write_only_mode_enabled?
        visitor = MultiTenant::ArelTenantVisitor.new(arel)

        visitor.contexts.each do |context|
          node = context.arel_node

          context.unhandled_relations.each do |relation|
            model = MultiTenant.multi_tenant_model_for_table(MultiTenant::TableNode.table_name(relation.arel_table))

            if MultiTenant.current_tenant_id
              enforcement_clause = MultiTenant::TenantEnforcementClause.new(relation.arel_table[model.partition_key])
              case node
              when Arel::Nodes::Join # Arel::Nodes::OuterJoin, Arel::Nodes::RightOuterJoin, Arel::Nodes::FullOuterJoin
                node.right.expr = node.right.expr.and(enforcement_clause)
              when Arel::Nodes::SelectCore
                if node.wheres.empty?
                  node.wheres = [enforcement_clause]
                elsif node.wheres[0].is_a?(Arel::Nodes::And)
                  node.wheres[0].children << enforcement_clause
                else
                  node.wheres[0] = enforcement_clause.and(node.wheres[0])
                end
              else
                raise 'UnknownContext'
              end
            end

            next unless node.is_a?(Arel::Nodes::SelectCore) || node.is_a?(Arel::Nodes::Join)

            node_list = if node.is_a? Arel::Nodes::Join
                          [node]
                        else
                          node.source.right
                        end

            node_list.select { |n| n.is_a? Arel::Nodes::Join }.each do |node_join|
              next unless node_join.right

              relation_right, relation_left = relations_from_node_join(node_join)

              next unless relation_right && relation_left

              model_right = MultiTenant.multi_tenant_model_for_table(MultiTenant::TableNode.table_name(relation_left))
              model_left = MultiTenant.multi_tenant_model_for_table(MultiTenant::TableNode.table_name(relation_right))
              next unless model_right && model_left

              join_enforcement_clause = MultiTenant::TenantJoinEnforcementClause.new(
                relation_right[model_right.partition_key], relation_left
              )
              node_join.right.expr = node_join.right.expr.and(join_enforcement_clause)
            end
          end
        end
      end

      arel
    end

    private

    def relations_from_node_join(node_join)
      if node_join.right.expr.is_a?(Arel::Nodes::Equality)
        return node_join.right.expr.right.relation, node_join.right.expr.left.relation
      end

      children = [node_join.right.expr.children].flatten

      tenant_applied = children.any? do |c|
        c.is_a?(MultiTenant::TenantEnforcementClause) || c.is_a?(MultiTenant::TenantJoinEnforcementClause)
      end
      return nil, nil if tenant_applied || children.empty?

      child = children.first.respond_to?(:children) ? children.first.children.first : children.first
      if child.right.respond_to?(:relation) && child.left.respond_to?(:relation)
        return child.right.relation, child.left.relation
      end

      [nil, nil]
    end
  end
end

require 'active_record/relation'
ActiveRecord::QueryMethods.prepend(MultiTenant::QueryMethodsExtensions)

module MultiTenantFindBy
  if ActiveRecord.gem_version >= Gem::Version.create('7.2.0')
    def cached_find_by_statement(connection, key, &block)
      return super unless respond_to?(:scoped_by_tenant?) && scoped_by_tenant?

      super(connection, Array.wrap(key) + [MultiTenant.current_tenant_id.to_s], &block)
    end
  else
    def cached_find_by_statement(key, &block)
      return super unless respond_to?(:scoped_by_tenant?) && scoped_by_tenant?

      super(Array.wrap(key) + [MultiTenant.current_tenant_id.to_s], &block)
    end
  end
end

ActiveSupport.on_load(:active_record) do |base|
  base.singleton_class.prepend(MultiTenantFindBy)
end
