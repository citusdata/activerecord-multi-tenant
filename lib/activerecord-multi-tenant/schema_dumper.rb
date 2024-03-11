module MultiTenant
  module SchemaDumper
    def initialize(connection, options = {})
      super(connection, options)

      citus_version = begin
        ActiveRecord::Migration.citus_version
      rescue StandardError
        # Handle the case where this gem is used with MySQL https://github.com/citusdata/activerecord-multi-tenant/issues/166
        nil
      end
      @distribution_columns =
        if citus_version.present?
          @connection.execute('SELECT logicalrelid::regclass AS table_name, column_to_column_name(logicalrelid, partkey) AS dist_col_name FROM pg_dist_partition').to_h do |v|
            [v['table_name'], v['dist_col_name']]
          end
        else
          {}
        end
    end

    def table(table, stream)
      super(table, stream)
      table_name = remove_prefix_and_suffix(table)
      distribution_column = @distribution_columns[table_name]
      if distribution_column
        stream.puts "  create_distributed_table(#{table_name.inspect}, #{distribution_column.inspect})"
        stream.puts
      elsif @distribution_columns.key?(table_name)
        stream.puts "  create_reference_table(#{table_name.inspect})"
        stream.puts
      end
    end
  end
end
