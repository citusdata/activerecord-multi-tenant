# Workaround for https://github.com/citusdata/citus/issues/1080
# "Support DISABLE/ENABLE TRIGGER ALL on distributed tables"

if Rails::VERSION::MAJOR < 5
  require 'active_record/connection_adapters/postgresql_adapter'

  module ActiveRecord
    module ConnectionAdapters
      class PostgreSQLAdapter < AbstractAdapter
        def supports_disable_referential_integrity?
          false
        end
      end
    end
  end
end
