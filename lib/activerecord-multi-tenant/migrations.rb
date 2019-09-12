module MultiTenant
  module MigrationExtensions
    def create_distributed_table(table_name, partition_key)
      return unless citus_version.present?
      execute "SELECT create_distributed_table($$#{table_name}$$, $$#{partition_key}$$)"
    end

    def create_reference_table(table_name)
      return unless citus_version.present?
      execute "SELECT create_reference_table($$#{table_name}$$)"
    end

    def execute_on_all_nodes(sql)
      execute sql

      case citus_version
      when '6.0'
        execute "SELECT citus_run_on_all_workers($$#{sql}$$)" # initial citus_tools.sql with different names
      when nil
        # Do nothing, this is regular Postgres
      else # 6.1 and newer
        execute "SELECT run_command_on_workers($$#{sql}$$)"
      end
    end

    def enable_extension_on_all_nodes(extension)
      execute_on_all_nodes "CREATE EXTENSION IF NOT EXISTS \"#{extension}\""
    end

    def citus_version
      execute("SELECT extversion FROM pg_extension WHERE extname = 'citus'").getvalue(0,0).try(:split, '-').try(:first)
    rescue ArgumentError => e
      raise unless e.message == "invalid tuple number 0"
    end
  end
end

if defined?(ActiveRecord::Migration)
  ActiveRecord::Migration.send(:include, MultiTenant::MigrationExtensions)
end

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      alias :orig_create_table :create_table
      alias :orig_change_table :change_table

      def change_primary_key(table_name, options)
        if !options[:partition_key] || options[:partition_key].to_s == 'id'
          return
        end

        pkey_columns = ['id', options[:partition_key]]

        # we are here comparing the columns in the primary key on the database and the one in the migration file
        query = ActiveRecord::Base::sanitize_sql_array(["select kcu.column_name as key_column " \
                                 "from information_schema.table_constraints tco "\
                                 "join information_schema.key_column_usage kcu " \
                                 "ON kcu.constraint_name = tco.constraint_name " \
                                 "AND kcu.constraint_schema = tco.constraint_schema "\
                                 "WHERE tco.constraint_type = 'PRIMARY KEY' " \
                                 "AND tco.constraint_name = '%s_pkey'", table_name])
        columns_result = execute(query)

        if columns_result.present?
          columns = columns_result.values.map(&:first)

          if columns.length != pkey_columns.length
            execute "ALTER TABLE #{table_name} DROP CONSTRAINT IF EXISTS #{table_name}_pkey"
            execute "ALTER TABLE #{table_name} ADD PRIMARY KEY(\"#{options[:partition_key]}\", id)"
          end
        end

      end

      def create_table(table_name, options = {}, &block)
        ret = orig_create_table(table_name, options.except(:partition_key), &block)
        change_primary_key(table_name, options)
        ret
      end

      def change_table(table_name, options, &block)
        ret = nil
        if block
          ret = orig_change_table(table_name, options.except(:partition_key), &block)
        end
        change_primary_key(table_name, options)
        ret
      end
    end
  end
end
