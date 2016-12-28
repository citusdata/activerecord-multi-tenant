# Note that the actual details here are subject to change, and you should avoid
# calling acts_as_tenant methods directly as a user of this library
require 'acts_as_tenant'

module MultiTenant
  def self.current_tenant
    ActsAsTenant.current_tenant
  end

  def self.current_tenant=(tenant)
    ActsAsTenant.current_tenant = tenant
  end

  def self.current_tenant_id
    ActsAsTenant.current_tenant.try(:id)
  end

  def self.with(tenant, &block)
    ActsAsTenant.with_tenant(tenant, &block)
  end

  def self.partition_key
    ActsAsTenant.fkey
  end

  def self.with_id(tenant_id, &block)
    MultiTenant.with(TenantIdWrapper.new(id: tenant_id), &block)
  end

  class TenantIdWrapper
    attr_reader :id

    def initialize(id:)
      @id = id
    end

    def new_record?; true; end
    def touch; nil; end
  end

  module ModelExtensions
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def multi_tenant(tenant, options = {})
        # Provide fallback primary key setting to ease integration with the typical Rails app
        self.primary_key = 'id' if primary_key.nil?

        # Typically we don't need to run on the tenant model itself
        if to_s.underscore.to_sym != tenant
          belongs_to(tenant)
          acts_as_tenant(tenant, options)

          around_save -> (record, block) { persisted? ? MultiTenant.with_id(record.public_send(tenant.to_s + '_id')) { block.call } : block.call }
          around_update -> (record, block) { MultiTenant.with_id(record.public_send(tenant.to_s + '_id')) { block.call } }
          around_destroy -> (record, block) { MultiTenant.with_id(record.public_send(tenant.to_s + '_id')) { block.call } }
        end

        # Workaround for https://github.com/citusdata/citus/issues/687
        if to_s.underscore.to_sym == tenant
          before_create -> { self.id ||= self.class.connection.select_value("SELECT nextval('" + [self.class.table_name, self.class.primary_key, 'seq'].join('_') + "'::regclass)") }
        end
      end
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.send(:include, MultiTenant::ModelExtensions)
end
