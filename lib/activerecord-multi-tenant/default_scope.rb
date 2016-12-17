class ActiveRecord::Base
  class << self
    alias :unscoped_orig :unscoped
    def unscoped
      if respond_to?(:scoped_by_tenant?) && MultiTenant.current_tenant_id
        unscoped_orig.where(arel_table[MultiTenant.partition_key].eq(MultiTenant.current_tenant_id))
      else
        unscoped_orig
      end
    end
  end
end
