class ActiveRecord::Base
  class << self
    alias :unscoped_orig :unscoped
    def unscoped
      if respond_to?(:scoped_by_tenant?) && ActsAsDistributed.current_tenant_id
        unscoped_orig.where(arel_table[ActsAsDistributed.partition_key].eq(ActsAsDistributed.current_tenant_id))
      else
        unscoped_orig
      end
    end
  end
end
