require 'request_store'

module MultiTenant
  @@tenant_klass = nil

  def self.set_tenant_klass(klass)
    @@tenant_klass = klass
  end

  def self.tenant_klass
    @@tenant_klass
  end

  def self.partition_key
    "#{@@tenant_klass.to_s}_id"
  end

  def self.current_tenant=(tenant)
    RequestStore.store[:current_tenant] = tenant
  end

  def self.current_tenant
    RequestStore.store[:current_tenant]
  end

  def self.current_tenant_id
    current_tenant.try(:id)
  end

  def self.with(tenant, &block)
    old_tenant = self.current_tenant
    self.current_tenant = tenant
    value = block.call
    return value

  ensure
    self.current_tenant = old_tenant
  end

  def self.with_id(tenant_id, &block)
    if MultiTenant.current_tenant_id == tenant_id
      block.call
    else
      MultiTenant.with(TenantIdWrapper.new(id: tenant_id), &block)
    end
  end

  class TenantIsImmutable < StandardError
  end

  class TenantIdWrapper
    attr_reader :id

    def initialize(id:)
      @id = id
    end

    def new_record?; true; end
    def touch; nil; end
  end
end
