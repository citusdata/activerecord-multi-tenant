module MultiTenant
  module ModelExtensionsClassMethods
    DEFAULT_ID_FIELD = 'id'.freeze

    def multi_tenant(tenant_name, options = {})
      if to_s.underscore.to_sym == tenant_name
        # This is the tenant model itself. Workaround for https://github.com/citusdata/citus/issues/687
        before_create -> { self.id ||= self.class.connection.select_value("SELECT nextval('" + [self.class.table_name, self.class.primary_key, 'seq'].join('_') + "'::regclass)") }
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
            return @primary_key = super || DEFAULT_ID_FIELD if Rails::VERSION::MAJOR < 5

            primary_object_keys = (connection.schema_cache.primary_keys(table_name) || []) - [partition_key]
            if primary_object_keys.size == 1
              @primary_key = primary_object_keys.first
            else
              @primary_key = DEFAULT_ID_FIELD
            end
          end
        end

        @partition_key = options[:partition_key] || MultiTenant.partition_key(tenant_name)
        partition_key = @partition_key

        # Create an implicit belongs_to association only if tenant class exists
        if MultiTenant.tenant_klass_defined?(tenant_name)
          belongs_to tenant_name, options.slice(:class_name, :inverse_of).merge(foreign_key: partition_key)
        end

        # Ensure all queries include the partition key
        default_scope lambda {
          if MultiTenant.current_tenant_id
            where(arel_table[partition_key].eq(MultiTenant.current_tenant_id))
          else
            Rails::VERSION::MAJOR < 4 ? scoped : all
          end
        }

        # New instances should have the tenant set
        before_validation Proc.new { |record|
          if MultiTenant.current_tenant_id && record.public_send(partition_key.to_sym).nil?
            record.public_send("#{partition_key}=".to_sym, MultiTenant.current_tenant_id)
          end
        }, on: :create

        # Validate that associations belong to the tenant, currently only for belongs_to
        polymorphic_foreign_keys = reflect_on_all_associations(:belongs_to).select do |a|
          a.options[:polymorphic]
        end.map { |a| a.foreign_key }

        reflect_on_all_associations(:belongs_to).each do |a|
          unless a == reflect_on_association(tenant_name) || polymorphic_foreign_keys.include?(a.foreign_key)
            association_class = a.options[:class_name].nil? ? a.name.to_s.classify.constantize : a.options[:class_name].constantize
            validates_each a.foreign_key.to_sym do |record, attr, value|
              primary_key = if association_class.respond_to?(:primary_key)
                              association_class.primary_key
                            else
                              a.primary_key
                            end.to_sym
              record.errors.add attr, 'association is invalid [MultiTenant]' unless value.nil? || association_class.where(primary_key => value).any?
            end
          end
        end

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
              if !MultiTenant.current_tenant_is_id? && MultiTenant.current_tenant_id && public_send(partition_key) == MultiTenant.current_tenant_id
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
