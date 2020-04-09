module MultiTenant
  module ControllerExtensions
    def set_current_tenant_through_filter
      self.class_eval do
        if respond_to?(:helper_method)
          helper_method :current_tenant
        end

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

ActiveSupport.on_load(:action_controller) do |base|
  base.extend MultiTenant::ControllerExtensions
end
