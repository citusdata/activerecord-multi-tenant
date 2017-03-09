require 'active_record'

class ActiveRecord::Base
  class << self
    alias :unscoped_orig :unscoped
    def unscoped
      scope = if respond_to?(:scoped_by_tenant?) && MultiTenant.current_tenant_id
        unscoped_orig.where(arel_table[self.partition_key].eq(MultiTenant.current_tenant_id))
      else
        unscoped_orig
      end

      block_given? ? scope.scoping { yield } : scope
    end
  end
end
