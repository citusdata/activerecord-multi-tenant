# Workaround for https://github.com/citusdata/citus/issues/1236
# "SELECT ... FOR UPDATE is not supported for router-plannable queries"

class ActiveRecord::Base
  alias lock_orig lock!

  def lock!(lock: true)
    if lock && persisted? && self.class.respond_to?(:scoped_by_tenant?) &&
       MultiTenant.current_tenant_id && MultiTenant.with_lock_workaround_enabled?
      self.class.unscoped.where(id: id).update_all(id: id) # No-op UPDATE that locks the row
      reload # This is just to act similar to the default ActiveRecord approach, in case someone relies on the reload
      self
    else
      lock_orig(lock)
    end
  end
end
