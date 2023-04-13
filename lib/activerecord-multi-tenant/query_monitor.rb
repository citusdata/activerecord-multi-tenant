# Add generic warning when queries fail and there is no tenant set
module MultiTenant
  # Option to enable query monitor
  @@enable_query_monitor = false

  def self.enable_query_monitor
    @@enable_query_monitor = true;
  end

  def self.query_monitor_enabled?
    @@enable_query_monitor;
  end

  class QueryMonitor
    def start(name, id, payload)
      ;
    end

    def finish(name, id, payload)
      return unless MultiTenant.query_monitor_enabled?
      return unless payload[:exception].present? && MultiTenant.current_tenant_id.nil?
      Rails.logger.info 'WARNING: Tenant not present - make sure to add MultiTenant.with(tenant) { ... }'
    end
  end
end

ActiveSupport::Notifications.subscribe('sql.active_record', MultiTenant::QueryMonitor.new)
