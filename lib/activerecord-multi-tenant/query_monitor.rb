# Add generic warning when queries fail and there is no tenant set
module MultiTenant
  # rubocop:disable Style/ClassVars
  # Option to enable query monitor
  @@enable_query_monitor = false

  def self.enable_query_monitor
    @@enable_query_monitor = true
  end

  def self.query_monitor_enabled?
    @@enable_query_monitor
  end

  # rubocop:enable Style/ClassVars

  class QueryMonitor
    def start(_name, _id, _payload) end

    def finish(_name, _id, payload)
      return unless MultiTenant.query_monitor_enabled?

      return unless payload[:exception].present? && MultiTenant.current_tenant_id.nil?

      Rails.logger.info 'WARNING: Tenant not present - make sure to add MultiTenant.with(tenant) { ... }'
    end
  end
end

ActiveSupport::Notifications.subscribe('sql.active_record', MultiTenant::QueryMonitor.new)
