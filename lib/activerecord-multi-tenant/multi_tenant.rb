require 'request_store'

module MultiTenant
  def self.tenant_klass_defined?(tenant_name)
    !!tenant_name.to_s.classify.safe_constantize
  end

  def self.partition_key(tenant_name)
    "#{tenant_name.to_s}_id"
  end

  # Workaroud to make "with_lock" work until https://github.com/citusdata/citus/issues/1236 is fixed
  @@enable_with_lock_workaround = false
  def self.enable_with_lock_workaround; @@enable_with_lock_workaround = true; end
  def self.with_lock_workaround_enabled?; @@enable_with_lock_workaround; end

  def self.current_tenant=(tenant)
    RequestStore.store[:current_tenant] = tenant
  end

  def self.current_tenant
    RequestStore.store[:current_tenant]
  end

  def self.current_tenant_id
    current_tenant_is_id? ? current_tenant : current_tenant.try(:id)
  end

  def self.current_tenant_is_id?
    current_tenant.is_a?(String) || current_tenant.is_a?(Integer)
  end

  def self.with(tenant, &block)
    return block.call if self.current_tenant == tenant
    old_tenant = self.current_tenant
    begin
      self.current_tenant = tenant
      return block.call
    ensure
      self.current_tenant = old_tenant
    end
  end

  # Preserve backward compatibility for people using .with_id
  singleton_class.send(:alias_method, :with_id, :with)

  class TenantIsImmutable < StandardError
  end
end
