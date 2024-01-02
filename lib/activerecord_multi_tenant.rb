# frozen_string_literal: true

require_relative 'activerecord-multi-tenant/controller_extensions' if Object.const_defined?(:ActionController)
require_relative 'activerecord-multi-tenant/copy_from_client'
require_relative 'activerecord-multi-tenant/fast_truncate'
require_relative 'activerecord-multi-tenant/migrations'
require_relative 'activerecord-multi-tenant/model_extensions'
require_relative 'activerecord-multi-tenant/multi_tenant'
require_relative 'activerecord-multi-tenant/query_rewriter'
require_relative 'activerecord-multi-tenant/query_monitor'
require_relative 'activerecord-multi-tenant/table_node'
require_relative 'activerecord-multi-tenant/version'
require_relative 'activerecord-multi-tenant/habtm'
require_relative 'activerecord-multi-tenant/relation_extension'
