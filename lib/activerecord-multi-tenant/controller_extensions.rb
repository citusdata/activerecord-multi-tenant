# frozen_string_literal: true

module MultiTenant
  module ControllerExtensions
    def set_current_tenant_through_filter
      class_eval do
        # Define current_tenant as a helper method, making it available in views
        helper_method :current_tenant if respond_to?(:helper_method)

        private

        # rubocop:disable Naming/AccessorMethodName
        # Define a setter method to set the current tenant object in a global variable
        def set_current_tenant(current_tenant_object)
          MultiTenant.current_tenant = current_tenant_object
        end
        # rubocop:enable Naming/AccessorMethodName

        def current_tenant
          MultiTenant.current_tenant
        end
      end
    end
  end
end

# Extend the ControllerExtensions module into ActionController::Base class in Rails
# making these controller extensions available in all controllers in the application
ActiveSupport.on_load(:action_controller) do |base|
  base.extend MultiTenant::ControllerExtensions
end
