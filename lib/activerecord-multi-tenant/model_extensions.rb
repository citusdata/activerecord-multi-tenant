module MultiTenant
  module ModelExtensionsClassMethods
    DEFAULT_ID_FIELD = 'id'.freeze

    def multi_tenant(tenant, options = {})
      # Workaround for https://github.com/citusdata/citus/issues/687
      if to_s.underscore.to_sym == tenant
        before_create -> { self.id ||= self.class.connection.select_value("SELECT nextval('" + [self.class.table_name, self.class.primary_key, 'seq'].join('_') + "'::regclass)") }
      end

      # Typically we don't need to run on the tenant model itself
      if to_s.underscore.to_sym != tenant
        MultiTenant.set_tenant_klass(tenant)

        class << self
          def scoped_by_tenant?
            true
          end

          def partition_key
            @@partition_key
          end

          if Rails::VERSION::MAJOR >= 5
            def primary_key
              primary_object_keys = (connection.schema_cache.primary_keys(table_name) || []) - [partition_key]
              if primary_object_keys.size == 1
                primary_object_keys.first
              else
                DEFAULT_ID_FIELD
              end
            end
          end
        end

        @@partition_key = options[:partition_key] || MultiTenant.partition_key
        partition_key = @@partition_key

        if MultiTenant.tenant_klass_defined?
          # Create the association if tenant klass is a model
          belongs_to tenant, options.slice(:class_name, :inverse_of).merge(foreign_key: partition_key)
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
          unless a == reflect_on_association(tenant) || polymorphic_foreign_keys.include?(a.foreign_key)
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
          define_method "#{partition_key}=" do |integer|
            write_attribute("#{partition_key}", integer)
            raise MultiTenant::TenantIsImmutable if send("#{partition_key}_changed?") && persisted? && !send("#{partition_key}_was").nil?
            integer
          end

          define_method "#{MultiTenant.tenant_klass.to_s}=" do |model|
            super(model)
            raise MultiTenant::TenantIsImmutable if send("#{partition_key}_changed?") && persisted? && !send("#{partition_key}_was").nil?
            model
          end

          define_method "#{MultiTenant.tenant_klass.to_s}" do
            if !MultiTenant.current_tenant.nil? && !MultiTenant.current_tenant.is_a?(MultiTenant::TenantIdWrapper) && public_send(partition_key) == MultiTenant.current_tenant.id
              return MultiTenant.current_tenant
            else
              super()
            end
          end
        end
        include to_include

        around_save -> (record, block) {
          if persisted? && MultiTenant.current_tenant_id.nil?
            MultiTenant.with_id(record.public_send(partition_key)) { block.call }
          else
            block.call
          end
        }

        around_update -> (record, block) {
          if MultiTenant.current_tenant_id.nil?
            MultiTenant.with_id(record.public_send(partition_key)) { block.call }
          else
            block.call
          end
        }

        around_destroy -> (record, block) {
          if MultiTenant.current_tenant_id.nil?
            MultiTenant.with_id(record.public_send(partition_key)) { block.call }
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
