# frozen_string_literal: true

require_relative 'multi_tenant'

module MultiTenant
  # Extension to the model to allow scoping of models to the current tenant. This is done by adding
  # the multitenant method to the models that need to be scoped. This method is called in the
  # model declaration.
  # Adds scoped_by_tenant? partition_key, primary_key and inherited methods to the model
  module ModelExtensionsClassMethods
    DEFAULT_ID_FIELD = 'id'
    # executes when multi_tenant method is called in the model. This method adds the following
    # methods to the model that calls it.
    # scoped_by_tenant? - returns true if the model is scoped by tenant
    # partition_key - returns the partition key for the model
    # primary_key - returns the primary key for the model
    #
    def multi_tenant(tenant_name, options = {})
      if to_s.underscore.to_sym == tenant_name || (!table_name.nil? && table_name.singularize.to_sym == tenant_name)
        unless MultiTenant.with_write_only_mode_enabled?
          # This is the tenant model itself. Workaround for https://github.com/citusdata/citus/issues/687
          before_create lambda {
            id = if self.class.columns_hash[self.class.primary_key].type == :uuid
                   SecureRandom.uuid
                 else
                   self.class.connection.select_value(
                     "SELECT nextval('#{self.class.table_name}_#{self.class.primary_key}_seq'::regclass)"
                   )
                 end
            self.id ||= id
          }
        end
      else
        class << self
          def scoped_by_tenant?
            true
          end

          # Allow partition_key to be set from a superclass if not already set in this class
          def partition_key
            @partition_key ||= ancestors.detect { |k| k.instance_variable_get(:@partition_key) }
                                        .try(:instance_variable_get, :@partition_key)
          end

          def reset_primary_key
            primary_object_keys = Array.wrap(connection.schema_cache.primary_keys(table_name)) - [partition_key]

            self.primary_key = if primary_object_keys.size == 1
                                 primary_object_keys.first
                               elsif table_name &&
                                     connection.schema_cache.columns_hash(table_name).include?(DEFAULT_ID_FIELD)
                                 DEFAULT_ID_FIELD
                               end
          end

          def inherited(subclass)
            super
            MultiTenant.register_multi_tenant_model(subclass)
          end
        end

        MultiTenant.register_multi_tenant_model(self)

        @partition_key = options[:partition_key] || MultiTenant.partition_key(tenant_name)
        partition_key = @partition_key

        # Create an implicit belongs_to association only if tenant class exists
        if MultiTenant.tenant_klass_defined?(tenant_name, options)
          belongs_to(
            tenant_name,
            **options.slice(:class_name, :inverse_of, :optional),
            foreign_key: options[:partition_key]
          )
        end

        # New instances should have the tenant set
        after_initialize proc { |record|
          if MultiTenant.current_tenant_id &&
             (!record.attribute_present?(partition_key) || record.public_send(partition_key.to_sym).nil?)
            record.public_send(:"#{partition_key}=", MultiTenant.current_tenant_id)
          end
        }

        # Below block adds the following methods to the model that calls it.
        # partition_key= - returns the partition key for the model.class << self 'partition' method defined above
        # is the getter method. Here, there is additional check to assure that the tenant id is not changed once set
        # tenant_name- returns the name of the tenant model. Its setter and getter methods defined separately
        # Getter checks for the tenant association and if it is not loaded, returns the current tenant id set
        # in the MultiTenant module
        to_include = Module.new do
          define_method "#{partition_key}=" do |tenant_id|
            write_attribute(partition_key.to_s, tenant_id)

            # Rails 5 `attribute_will_change!` uses the attribute-method-call rather than `read_attribute`
            # and will raise ActiveModel::MissingAttributeError if that column was not selected.
            # This is rescued as NoMethodError and in MRI attribute_was is assigned an arbitrary Object
            was = send("#{partition_key}_was")
            was_nil_or_skipped = was.nil? || was.instance_of?(Object)

            if send("#{partition_key}_changed?") && persisted? && !was_nil_or_skipped
              raise MultiTenant::TenantIsImmutable
            end

            tenant_id
          end

          if MultiTenant.tenant_klass_defined?(tenant_name, options)
            define_method "#{tenant_name}=" do |model|
              super(model)
              if send("#{partition_key}_changed?") && persisted? && !send("#{partition_key}_was").nil?
                raise MultiTenant::TenantIsImmutable
              end

              model
            end

            define_method tenant_name.to_s do
              if !association(tenant_name.to_sym).loaded? && !MultiTenant.current_tenant_is_id? &&
                 MultiTenant.current_tenant_id && public_send(partition_key) == MultiTenant.current_tenant_id
                MultiTenant.current_tenant
              else
                super()
              end
            end
          end
        end
        include to_include

        # Below blocks sets tenant_id for the current session with the tenant_id of the record
        # If the tenant is not set for the `session.After` the save operation current session tenant is set to nil
        # If tenant is set for the session, save operation is performed as it is
        around_save lambda { |record, block|
          record_tenant = record.attribute_was(partition_key)
          if persisted? && MultiTenant.current_tenant_id.nil? && !record_tenant.nil?
            MultiTenant.with(record.public_send(partition_key)) { block.call }
          else
            block.call
          end
        }

        around_update lambda { |record, block|
          record_tenant = record.attribute_was(partition_key)
          if MultiTenant.current_tenant_id.nil? && !record_tenant.nil?
            MultiTenant.with(record.public_send(partition_key)) { block.call }
          else
            block.call
          end
        }

        around_destroy lambda { |record, block|
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

# Below code block is executed on Model, Associations and CollectionProxy objects
# when ActiveRecord is loaded and decorates defined methods with MultiTenant.with function.
# Additionally, adds aliases for some operators.
ActiveSupport.on_load(:active_record) do |base|
  base.extend MultiTenant::ModelExtensionsClassMethods

  # Ensure we have current_tenant_id in where clause when a cached ActiveRecord instance is being reloaded,
  # or update_columns without callbacks is called
  MultiTenant.wrap_methods(ActiveRecord::Base, 'self', :delete, :reload, :update_columns)

  # Any queuries fired for fetching a singular association have the correct current_tenant_id in WHERE clause
  # reload is called anytime any record's association is accessed
  MultiTenant.wrap_methods(ActiveRecord::Associations::Association, 'owner', :reload)

  # For collection associations, we need to wrap multiple methods in returned proxy so that
  # any queries have the correct current_tenant_id in WHERE clause
  ActiveRecord::Associations::CollectionProxy.alias_method \
    :equals_mt, :== # Hack to prevent syntax error due to invalid method name
  ActiveRecord::Associations::CollectionProxy.alias_method \
    :append_mt, :<< # Hack to prevent syntax error due to invalid method name
  MultiTenant.wrap_methods(ActiveRecord::Associations::CollectionProxy, '@association.owner',
                           :find, :last, :take, :build, :create, :create!, :replace, :delete_all,
                           :destroy_all, :delete, :destroy, :calculate, :pluck, :size, :empty?, :include?, :equals_mt,
                           :records, :append_mt, :find_nth_with_limit, :find_nth_from_last, :null_scope?,
                           :find_from_target?, :exec_queries)
  ActiveRecord::Associations::CollectionProxy.alias_method :==, :equals_mt
  ActiveRecord::Associations::CollectionProxy.alias_method :<<, :append_mt
end

# skips statement caching for classes that is Multi-tenant or has a multi-tenant relation
module MultiTenant
  module AssociationExtensions
    def skip_statement_cache?(*scope)
      return true if klass.respond_to?(:scoped_by_tenant?) && klass.scoped_by_tenant?

      if reflection.through_reflection
        through_klass = reflection.through_reflection.klass
        return true if through_klass.respond_to?(:scoped_by_tenant?) && through_klass.scoped_by_tenant?
      end

      super
    end
  end
end

ActiveRecord::Associations::Association.prepend(MultiTenant::AssociationExtensions)
