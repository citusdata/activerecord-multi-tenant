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

  class BindValueSubstitute
    def initialize(column_type)
      @column_type = column_type
    end

    def value_for_database
      MultiTenant.current_tenant_id
    end

    def value
      MultiTenant.current_tenant_id
    end

    def cast_type
      @column_type
    end
  end

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

    # Citus does not support cross-partition COUNT(DISTINCT) at the moment
    # Note this will cause counts to be off with left joins / eager loads
    if projections.is_a?(Arel::Nodes::Count)
      projections.distinct = false
    end
    arel
  end
end

require 'active_record/relation'
module ActiveRecord
  module QueryMethods
    alias :build_arel_orig :build_arel
    def build_arel
      arel = build_arel_orig

      unless MultiTenant.with_write_only_mode_enabled?
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
                           elsif MultiTenant.current_tenant_id
                             if ActiveRecord::VERSION::MAJOR >= 5
                               #arel.bind_values << Relation::QueryAttribute.new(model.partition_key, MultiTenant.current_tenant_id, model.type_for_attribute(model.partition_key))
                               arel.bind_values << MultiTenant::BindValueSubstitute.new(model.columns_hash[model.partition_key])
                               Arel::Nodes::BindParam.new
                             else
                               #arel.bind_values << [model.columns_hash[model.partition_key], MultiTenant.current_tenant_id]
                               # FIXME
                               MultiTenant.current_tenant_id
                             end
                           end

            known_relations << relation
            next unless tenant_value

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

        arel = MultiTenant.convert_distinct_to_group_by(arel) unless MultiTenant.current_tenant
      end

      arel
    end
  end
end
