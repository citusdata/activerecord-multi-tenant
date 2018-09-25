module MultiTenant
  module ModelExtensionsClassMethods
    DEFAULT_ID_FIELD = 'id'.freeze

    def multi_tenant(tenant_name, options = {})
      if to_s.underscore.to_sym == tenant_name
        unless MultiTenant.with_write_only_mode_enabled?
          # This is the tenant model itself. Workaround for https://github.com/citusdata/citus/issues/687
          before_create -> { self.id ||= self.class.connection.select_value("SELECT nextval('" + [self.class.table_name, self.class.primary_key, 'seq'].join('_') + "'::regclass)") }
        end
      else
        class << self
          def scoped_by_tenant?
            true
          end

          # Allow partition_key to be set from a superclass if not already set in this class
          def partition_key
            @partition_key ||= ancestors.detect{ |k| k.instance_variable_get(:@partition_key) }
                                 .try(:instance_variable_get, :@partition_key)
          end

          # Avoid primary_key errors when using composite primary keys (e.g. id, tenant_id)
          def primary_key
            return @primary_key if @primary_key
            return @primary_key = super || DEFAULT_ID_FIELD if ::ActiveRecord::VERSION::MAJOR < 5

            primary_object_keys = Array.wrap(connection.schema_cache.primary_keys(table_name)) - [partition_key]
            if primary_object_keys.size == 1
              @primary_key = primary_object_keys.first
            else
              @primary_key = DEFAULT_ID_FIELD
            end
          end

          def inherited(subclass)
            super
            MultiTenant.register_multi_tenant_model(subclass.table_name, subclass) if subclass.table_name
          end
        end

        MultiTenant.register_multi_tenant_model(table_name, self) if table_name

        @partition_key = options[:partition_key] || MultiTenant.partition_key(tenant_name)
        partition_key = @partition_key

        # Create an implicit belongs_to association only if tenant class exists
        if MultiTenant.tenant_klass_defined?(tenant_name)
          belongs_to tenant_name, options.slice(:class_name, :inverse_of).merge(foreign_key: options[:partition_key])
        end

        # New instances should have the tenant set
        after_initialize Proc.new { |record|
          if MultiTenant.current_tenant_id && record.public_send(partition_key.to_sym).nil?
            record.public_send("#{partition_key}=".to_sym, MultiTenant.current_tenant_id)
          end
        }

        to_include = Module.new do
          define_method "#{partition_key}=" do |tenant_id|
            write_attribute("#{partition_key}", tenant_id)
            raise MultiTenant::TenantIsImmutable if send("#{partition_key}_changed?") && persisted? && !send("#{partition_key}_was").nil?
            tenant_id
          end

          if MultiTenant.tenant_klass_defined?(tenant_name)
            define_method "#{tenant_name}=" do |model|
              super(model)
              raise MultiTenant::TenantIsImmutable if send("#{partition_key}_changed?") && persisted? && !send("#{partition_key}_was").nil?
              model
            end

            define_method "#{tenant_name}" do
              if !association(tenant_name.to_sym).loaded? && !MultiTenant.current_tenant_is_id? && MultiTenant.current_tenant_id && public_send(partition_key) == MultiTenant.current_tenant_id
                return MultiTenant.current_tenant
              else
                super()
              end
            end
          end
        end
        include to_include

        around_save -> (record, block) {
          if persisted? && MultiTenant.current_tenant_id.nil?
            MultiTenant.with(record.public_send(partition_key)) { block.call }
          else
            block.call
          end
        }

        around_update -> (record, block) {
          if MultiTenant.current_tenant_id.nil?
            MultiTenant.with(record.public_send(partition_key)) { block.call }
          else
            block.call
          end
        }

        around_destroy -> (record, block) {
          if MultiTenant.current_tenant_id.nil?
            MultiTenant.with(record.public_send(partition_key)) { block.call }
          else
            block.call
          end
        }
      end
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend(MultiTenant::ModelExtensionsClassMethods)
end

class ActiveRecord::Associations::Association
  alias skip_statement_cache_orig skip_statement_cache?
  def skip_statement_cache?(*scope)
    return true if klass.respond_to?(:scoped_by_tenant?) && klass.scoped_by_tenant?
    skip_statement_cache_orig(*scope)
  end
end
