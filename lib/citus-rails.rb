require 'acts_as_tenant'

# Note that the actual details here are subject to change, and you should avoid
# calling acts_as_tenant methods directly as a user of this library
module ActsAsDistributed
  module ModelExtensions
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def acts_as_distributed(tenant, options = {})
        # Typically we don't need to run on the tenant model itself
        if to_s.underscore.to_sym != tenant
          belongs_to(tenant)
          acts_as_tenant(tenant, options)
        end

        # Workaround for https://github.com/citusdata/citus/issues/687
        if to_s.underscore.to_sym == tenant
          before_create -> { self.id ||= self.class.connection.select_value("SELECT nextval('" + [self.class.table_name, self.class.primary_key, 'seq'].join('_') + "'::regclass)") }
        end
      end
    end
  end

  module MigrationExtensions
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
    end

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

  def self.current_tenant
    ActsAsDistributed.current_tenant
  end

  def self.with(tenant, &block)
    ActsAsTenant.with_tenant(tenant, &block)
  end

  def self.with_id(tenant_id, &block)
    # TODO
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.send(:include, ActsAsDistributed::ModelExtensions)
end

if defined?(ActiveRecord::Migration)
  ActiveRecord::Migration.send(:include, ActsAsDistributed::MigrationExtensions)
end
