# Disable Rails trigger enable/disable mechanism used for test cases, since
# DISABLE TRIGGER is not supported on distributed tables.

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
