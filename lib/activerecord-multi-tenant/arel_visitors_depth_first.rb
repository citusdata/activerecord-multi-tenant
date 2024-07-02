# frozen_string_literal: true

module MultiTenant
  class ArelVisitorsDepthFirst < Arel::Visitors::Visitor
    def initialize(block = nil)
      @block = block || proc
      super()
    end

    private

    def visit(obj, _ = nil)
      super
      @block.call obj
    end

    def unary(obj)
      visit obj.expr
    end
    alias visit_Arel_Nodes_Else              unary
    alias visit_Arel_Nodes_Group             unary
    alias visit_Arel_Nodes_Cube              unary
    alias visit_Arel_Nodes_RollUp            unary
    alias visit_Arel_Nodes_GroupingSet       unary
    alias visit_Arel_Nodes_GroupingElement   unary
    alias visit_Arel_Nodes_Grouping          unary
    alias visit_Arel_Nodes_Having            unary
    alias visit_Arel_Nodes_Lateral           unary
    alias visit_Arel_Nodes_Limit             unary
    alias visit_Arel_Nodes_Not               unary
    alias visit_Arel_Nodes_Offset            unary
    alias visit_Arel_Nodes_On                unary
    alias visit_Arel_Nodes_Ordering          unary
    alias visit_Arel_Nodes_Ascending         unary
    alias visit_Arel_Nodes_Descending        unary
    alias visit_Arel_Nodes_UnqualifiedColumn unary
    alias visit_Arel_Nodes_OptimizerHints    unary
    alias visit_Arel_Nodes_ValuesList        unary

    def function(obj)
      visit obj.expressions
      visit obj.alias
      visit obj.distinct
    end
    alias visit_Arel_Nodes_Avg    function
    alias visit_Arel_Nodes_Exists function
    alias visit_Arel_Nodes_Max    function
    alias visit_Arel_Nodes_Min    function
    alias visit_Arel_Nodes_Sum    function

    # rubocop:disable Naming/MethodName

    def visit_Arel_Nodes_NamedFunction(obj)
      visit obj.name
      visit obj.expressions
      visit obj.distinct
      visit obj.alias
    end

    def visit_Arel_Nodes_Count(obj)
      visit obj.expressions
      visit obj.alias
      visit obj.distinct
    end

    def visit_Arel_Nodes_Case(obj)
      visit obj.case
      visit obj.conditions
      visit obj.default
    end

    def nary(obj)
      obj.children.each { |child| visit child }
    end
    alias visit_Arel_Nodes_And nary

    def binary(obj)
      visit obj.left
      visit obj.right
    end
    alias visit_Arel_Nodes_As                 binary
    alias visit_Arel_Nodes_Assignment         binary
    alias visit_Arel_Nodes_Between            binary
    alias visit_Arel_Nodes_Concat             binary
    alias visit_Arel_Nodes_DeleteStatement    binary
    alias visit_Arel_Nodes_DoesNotMatch       binary
    alias visit_Arel_Nodes_Equality           binary
    alias visit_Arel_Nodes_FullOuterJoin      binary
    alias visit_Arel_Nodes_GreaterThan        binary
    alias visit_Arel_Nodes_GreaterThanOrEqual binary
    alias visit_Arel_Nodes_In                 binary
    alias visit_Arel_Nodes_InfixOperation     binary
    alias visit_Arel_Nodes_JoinSource         binary
    alias visit_Arel_Nodes_InnerJoin          binary
    alias visit_Arel_Nodes_LessThan           binary
    alias visit_Arel_Nodes_LessThanOrEqual    binary
    alias visit_Arel_Nodes_Matches            binary
    alias visit_Arel_Nodes_NotEqual           binary
    alias visit_Arel_Nodes_NotIn              binary
    alias visit_Arel_Nodes_NotRegexp          binary
    alias visit_Arel_Nodes_IsNotDistinctFrom  binary
    alias visit_Arel_Nodes_IsDistinctFrom     binary
    alias visit_Arel_Nodes_Or                 binary
    alias visit_Arel_Nodes_OuterJoin          binary
    alias visit_Arel_Nodes_Regexp             binary
    alias visit_Arel_Nodes_RightOuterJoin     binary
    alias visit_Arel_Nodes_TableAlias         binary
    alias visit_Arel_Nodes_When               binary

    def visit_Arel_Nodes_StringJoin(obj)
      visit obj.left
    end

    def visit_Arel_Attribute(obj)
      visit obj.relation
      visit obj.name
    end
    alias visit_Arel_Attributes_Integer visit_Arel_Attribute
    alias visit_Arel_Attributes_Float visit_Arel_Attribute
    alias visit_Arel_Attributes_String visit_Arel_Attribute
    alias visit_Arel_Attributes_Time visit_Arel_Attribute
    alias visit_Arel_Attributes_Boolean visit_Arel_Attribute
    alias visit_Arel_Attributes_Attribute visit_Arel_Attribute
    alias visit_Arel_Attributes_Decimal visit_Arel_Attribute

    def visit_Arel_Table(obj)
      visit obj.name
    end

    def terminal(obj); end
    alias visit_ActiveSupport_Multibyte_Chars terminal
    alias visit_ActiveSupport_StringInquirer  terminal
    alias visit_Arel_Nodes_Lock               terminal
    alias visit_Arel_Nodes_Node               terminal
    alias visit_Arel_Nodes_SqlLiteral         terminal
    alias visit_Arel_Nodes_BindParam          terminal
    alias visit_Arel_Nodes_Window             terminal
    alias visit_Arel_Nodes_True               terminal
    alias visit_Arel_Nodes_False              terminal
    alias visit_BigDecimal                    terminal
    alias visit_Class                         terminal
    alias visit_Date                          terminal
    alias visit_DateTime                      terminal
    alias visit_FalseClass                    terminal
    alias visit_Float                         terminal
    alias visit_Integer                       terminal
    alias visit_NilClass                      terminal
    alias visit_String                        terminal
    alias visit_Symbol                        terminal
    alias visit_Time                          terminal
    alias visit_TrueClass                     terminal

    def visit_Arel_Nodes_InsertStatement(obj)
      visit obj.relation
      visit obj.columns
      visit obj.values
    end

    def visit_Arel_Nodes_SelectCore(obj)
      visit obj.projections
      visit obj.source
      visit obj.wheres
      visit obj.groups
      visit obj.windows
      visit obj.havings
    end

    def visit_Arel_SelectManager(obj)
      visit obj.ast
    end

    def visit_Arel_Nodes_SelectStatement(obj)
      visit obj.cores
      visit obj.orders
      visit obj.limit
      visit obj.lock
      visit obj.offset
    end

    def visit_Arel_Nodes_UpdateStatement(obj)
      visit obj.relation
      visit obj.values
      visit obj.wheres
      visit obj.orders
      visit obj.limit
    end

    def visit_Arel_Nodes_Comment(obj)
      visit obj.values
    end

    def visit_Array(obj)
      obj.each { |i| visit i }
    end
    alias visit_Set visit_Array

    def visit_Hash(obj)
      obj.each do |k, v|
        visit(k)
        visit(v)
      end
    end

    DISPATCH = dispatch_cache

    # rubocop:disable Naming/AccessorMethodName
    def get_dispatch_cache
      DISPATCH
    end
    # rubocop:enable Naming/AccessorMethodName
    # rubocop:enable Naming/MethodName
  end
end
