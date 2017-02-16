# Workaround for https://github.com/citusdata/citus/issues/1236
# "SELECT ... FOR UPDATE is not supported for router-plannable queries"

class ActiveRecord::Base
  alias :with_lock_orig :with_lock
  def with_lock(&block)
    if self.class.respond_to?(:scoped_by_tenant?) && MultiTenant.current_tenant_id && MultiTenant.with_lock_workaround_enabled?
      transaction do
        self.class.unscoped.where(id: id).update_all(id: id) # No-op UPDATE that locks the row
        reload # This is just to act similar to the default Rails approach, in case someone relies on the reload
        yield
      end
    else
      with_lock_orig(&block)
    end
  end
end
