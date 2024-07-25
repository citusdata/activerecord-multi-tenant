module MultiTenant
  module SchemaDumper
    private

    def initialize(connection, options = {})
      super

      citus_version =
        begin
          ActiveRecord::Migration.citus_version
        rescue StandardError
          # Handle the case where this gem is used with MySQL https://github.com/citusdata/activerecord-multi-tenant/issues/166
          nil
        end
      @distribution_columns =
        if citus_version.present?
          query_to_execute = <<-SQL.strip
            SELECT logicalrelid::regclass AS table_name,
                   column_to_column_name(logicalrelid, partkey) AS dist_col_name
            FROM pg_dist_partition
          SQL
          @connection.execute(query_to_execute).to_h do |v|
            [v['table_name'], v['dist_col_name']]
          end
        else
          {}
        end
    end

    def table(table, stream)
      super
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

ActiveSupport.on_load(:active_record) do
  ActiveRecord::SchemaDumper.prepend(MultiTenant::SchemaDumper)
end
