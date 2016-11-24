module MultiTenant
  module MigrationExtensions
    def create_distributed_table(table_name, partition_key)
      execute "SELECT create_distributed_table($$#{table_name}$$, $$#{partition_key}$$)"
    end

    def execute_on_all_nodes(sql)
      execute sql
      execute "SELECT citus_run_on_all_workers($$#{sql}$$)"
    end

    def enable_extension_on_all_nodes(extension)
      execute_on_all_nodes "CREATE EXTENSION IF NOT EXISTS \"#{extension}\""
    end

    def enable_citus_tools
      execute <<-SQL
      CREATE OR REPLACE FUNCTION citus_run_on_all_workers(command text,
                            parallel bool default true,
                            OUT nodename text,
                            OUT nodeport int,
                            OUT success bool,
                            OUT result text)
        RETURNS SETOF record
        LANGUAGE plpgsql
        AS $function$
      DECLARE
        workers text[];
        ports int[];
        commands text[];
      BEGIN
        WITH citus_workers AS (
          SELECT * FROM master_get_active_worker_nodes() ORDER BY node_name, node_port)
        SELECT array_agg(node_name), array_agg(node_port), array_agg(command)
        INTO workers, ports, commands
        FROM citus_workers;

        RETURN QUERY SELECT * FROM master_run_on_worker(workers, ports, commands, parallel);
      END;
      $function$;
      SQL
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
      def create_table(table_name, options = {}, &block)
        ret = orig_create_table(table_name, options.except(:partition_key), &block)
        if options[:partition_key] && options[:partition_key].to_s != 'id'
          execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{table_name}_pkey"
          execute "ALTER TABLE #{table_name} ADD PRIMARY KEY(id, #{options[:partition_key]})"
        end
        ret
      end
    end
  end
end
