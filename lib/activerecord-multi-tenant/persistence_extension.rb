module ActiveRecord
  module Persistence
    alias :delete_orig :delete

    def delete
      if MultiTenant.multi_tenant_model_for_table(self.class.table_name).present? && persisted? && MultiTenant.current_tenant_id.nil?
        MultiTenant.with(self.public_send(self.class.partition_key)) { delete_orig }
      else
        delete_orig
      end
    end
  end
end
