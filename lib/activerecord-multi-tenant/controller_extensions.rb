module MultiTenant
  module ControllerExtensions
    def set_current_tenant_through_filter
      self.class_eval do
        helper_method :current_tenant

        private
          def set_current_tenant(current_tenant_object)
            MultiTenant.current_tenant = current_tenant_object
          end

          def current_tenant
            MultiTenant.current_tenant
          end
      end
    end
  end
end

if defined?(ActionController::Base)
  ActionController::Base.extend MultiTenant::ControllerExtensions
end
