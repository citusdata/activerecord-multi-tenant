require_relative 'activerecord-multi-tenant/controller_extensions' if Object.const_defined?(:ActionController)
require_relative 'activerecord-multi-tenant/copy_from_client'
require_relative 'activerecord-multi-tenant/fast_truncate'
require_relative 'activerecord-multi-tenant/model_extensions'
require_relative 'activerecord-multi-tenant/multi_tenant'
require_relative 'activerecord-multi-tenant/query_rewriter'
require_relative 'activerecord-multi-tenant/query_monitor'
require_relative 'activerecord-multi-tenant/version'
require_relative 'activerecord-multi-tenant/with_lock'
require_relative 'activerecord-multi-tenant/delete_operations'

ActiveSupport.on_load(:active_record) do
  require_relative 'activerecord-multi-tenant/migrations_extension'
  require_relative 'activerecord-multi-tenant/schema_dumper'
  require_relative 'activerecord-multi-tenant/schema_statements'

  ActiveRecord::Migration.include MultiTenant::MigrationExtensions
  ActiveRecord::SchemaDumper.prepend(MultiTenant::SchemaDumper)
end
