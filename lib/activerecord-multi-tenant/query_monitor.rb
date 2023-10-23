# frozen_string_literal: true

# Add generic warning when queries fail and there is no tenant set
# To handle this case, a QueryMonitor hook is created and registered
# to sql.active_record. This hook will log a warning when a query fails
# This hook is executed after the query is executed.
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
  # QueryMonitor class to log a warning when a query fails and there is no tenant set
  # start and finish methods are required to be register sql.active_record hook
  class QueryMonitor
    def start(_name, _id, _payload) end

    def finish(_name, _id, payload)
      return unless MultiTenant.query_monitor_enabled?

      return unless payload[:exception].present? && MultiTenant.current_tenant_id.nil?

      Rails.logger.info 'WARNING: Tenant not present - make sure to add MultiTenant.with(tenant) { ... }'
    end
  end
end
# Actual code to register the hook.
ActiveSupport::Notifications.subscribe('sql.active_record', MultiTenant::QueryMonitor.new)
