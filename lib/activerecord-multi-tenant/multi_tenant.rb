require 'request_store'

module MultiTenant
  def self.tenant_klass_defined?(tenant_name)
    !!tenant_name.to_s.classify.safe_constantize
  end

  def self.partition_key(tenant_name)
    "#{tenant_name.to_s}_id"
  end

  # In some cases we only have an ID - if defined we'll return the default tenant class in such cases
  def self.default_tenant_class=(tenant_class); @@default_tenant_class = tenant_class; end
  def self.default_tenant_class; @@default_tenant_class ||= nil; end

  # Write-only Mode - this only adds the tenant_id to new records, but doesn't
  # require its presence for SELECTs/UPDATEs/DELETEs
  def self.enable_write_only_mode; @@enable_write_only_mode = true; end
  def self.with_write_only_mode_enabled?; @@enable_write_only_mode ||= false; end

  # Workaroud to make "with_lock" work until https://github.com/citusdata/citus/issues/1236 is fixed
  @@enable_with_lock_workaround = false
  def self.enable_with_lock_workaround; @@enable_with_lock_workaround = true; end
  def self.with_lock_workaround_enabled?; @@enable_with_lock_workaround; end

  # Registry that maps table names to models (used by the query rewriter)
  def self.register_multi_tenant_model(table_name, model_klass)
    @@multi_tenant_models ||= {}
    @@multi_tenant_models[table_name.to_s] = model_klass
  end
  def self.multi_tenant_model_for_table(table_name)
    @@multi_tenant_models ||= {}
    @@multi_tenant_models[table_name.to_s]
  end

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

  def self.current_tenant_class
    if current_tenant_is_id?
      MultiTenant.default_tenant_class || fail('Only have tenant id, and no default tenant class set')
    elsif current_tenant
      MultiTenant.current_tenant.class.name
    end
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
