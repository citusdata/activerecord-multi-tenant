if Object.const_defined?(:ActionController)
  require_relative 'activerecord-multi-tenant/controller_extensions'
end
require_relative 'activerecord-multi-tenant/copy_from_client'
require_relative 'activerecord-multi-tenant/fast_truncate'
require_relative 'activerecord-multi-tenant/migrations'
require_relative 'activerecord-multi-tenant/model_extensions'
require_relative 'activerecord-multi-tenant/multi_tenant'
require_relative 'activerecord-multi-tenant/query_rewriter'
require_relative 'activerecord-multi-tenant/query_monitor'
require_relative 'activerecord-multi-tenant/version'
require_relative 'activerecord-multi-tenant/with_lock'
