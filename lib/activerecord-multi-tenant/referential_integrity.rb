# Workaround for https://github.com/citusdata/citus/issues/1080
# "Support DISABLE/ENABLE TRIGGER ALL on distributed tables"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ReferentialIntegrity
        def supports_disable_referential_integrity?
          false
        end

        def disable_referential_integrity
          yield
        end
      end
    end
  end
end
