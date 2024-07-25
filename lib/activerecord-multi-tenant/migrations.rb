# frozen_string_literal: true

module MultiTenant
  module MigrationExtensions
    def create_distributed_table(table_name, partition_key)
      return unless citus_version.present?

      reversible do |dir|
        dir.up do
          execute "SELECT create_distributed_table($$#{table_name}$$, $$#{partition_key}$$)"
        end
        dir.down do
          undistribute_table(table_name)
        end
      end
    end

    def create_reference_table(table_name)
      return unless citus_version.present?

      reversible do |dir|
        dir.up do
          execute "SELECT create_reference_table($$#{table_name}$$)"
        end
        dir.down do
          undistribute_table(table_name)
        end
      end
    end

    def undistribute_table(table_name)
      return unless citus_version.present?

      execute "SELECT undistribute_table($$#{table_name}$$)"
    end

    def rebalance_table_shards
      return unless citus_version.present?

      execute 'SELECT rebalance_table_shards()'
    end

    def execute_on_all_nodes(sql)
      execute sql

      case citus_version
      when '6.0'
        execute "SELECT citus_run_on_all_workers($$#{sql}$$)" # initial citus_tools.sql with different names
      when nil
        # Do nothing, this is regular Postgres
      else
        # 6.1 and newer
        execute "SELECT run_command_on_workers($$#{sql}$$)"
      end
    end

    def enable_extension_on_all_nodes(extension)
      execute_on_all_nodes "CREATE EXTENSION IF NOT EXISTS \"#{extension}\""
    end

    def citus_version
      execute("SELECT extversion FROM pg_extension WHERE extname = 'citus'").getvalue(0, 0).try(:split, '-').try(:first)
    rescue ArgumentError => e
      raise unless e.message == 'invalid tuple number 0'
    end
  end
end

ActiveRecord::Migration.include MultiTenant::MigrationExtensions if defined?(ActiveRecord::Migration)

module MultiTenant
  module SchemaStatementsExtensions
    def create_table(table_name, options = {}, &block)
      ret = super(table_name, **options.except(:partition_key), &block)
      if options[:id] != false && options[:partition_key] && options[:partition_key].to_s != 'id'
        execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{table_name}_pkey"
        execute "ALTER TABLE #{table_name} ADD PRIMARY KEY(\"#{options[:partition_key]}\", id)"
      end
      ret
    end
  end
end
ActiveRecord::ConnectionAdapters::SchemaStatements.prepend(MultiTenant::SchemaStatementsExtensions)
