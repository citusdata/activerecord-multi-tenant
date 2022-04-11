require 'active_support/current_attributes'

module MultiTenant
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :tenant
  end

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
  def self.register_multi_tenant_model(model_klass)
    @@multi_tenant_models ||= []
    @@multi_tenant_models.push(model_klass)

    remove_class_variable(:@@multi_tenant_model_table_names) if defined?(@@multi_tenant_model_table_names)
  end

  def self.multi_tenant_model_for_table(table_name)
    @@multi_tenant_models ||= []

    if !defined?(@@multi_tenant_model_table_names)
      @@multi_tenant_model_table_names = @@multi_tenant_models.map { |model|
        [model.table_name, model] if model.table_name
      }.compact.to_h
    end

    @@multi_tenant_model_table_names[table_name.to_s]
  end

  def self.multi_tenant_model_for_arel(arel)
    return nil unless arel.respond_to?(:ast)
    if arel.ast.relation.is_a? Arel::Nodes::JoinSource
      MultiTenant.multi_tenant_model_for_table(arel.ast.relation.left.table_name)
    else
      MultiTenant.multi_tenant_model_for_table(arel.ast.relation.table_name)
    end
  end

  def self.current_tenant=(tenant)
    Current.tenant = tenant
  end

  def self.current_tenant
    Current.tenant
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

  def self.load_current_tenant!
    return MultiTenant.current_tenant if MultiTenant.current_tenant && !current_tenant_is_id?
    raise 'MultiTenant.current_tenant must be set to load' if MultiTenant.current_tenant.nil?
    klass = MultiTenant.default_tenant_class || fail('Only have tenant id, and no default tenant class set')
    self.current_tenant = klass.find(MultiTenant.current_tenant_id)
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

  def self.without(&block)
    return block.call if self.current_tenant.nil?
    old_tenant = self.current_tenant
    begin
      self.current_tenant = nil
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
