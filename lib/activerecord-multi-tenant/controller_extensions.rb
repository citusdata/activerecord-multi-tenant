# frozen_string_literal: true

# Extension to the controller to allow setting the current tenant
# set_current_tenant and current_tenant methods are introduced
# to set and get the current tenant in the controllers that uses
# the MultiTenant module.
module MultiTenant
  module ControllerExtensions
    def set_current_tenant_through_filter
      class_eval do
        helper_method :current_tenant if respond_to?(:helper_method)

        private

        # rubocop:disable Naming/AccessorMethodName
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

# This block is executed when the file is loaded and
# makes the base class; ActionController::Base to
# extend the ControllerExtensions module.
# This will add the set_current_tenant and current_tenant
# in all the controllers that inherit from ActionController::Base
ActiveSupport.on_load(:action_controller) do |base|
  base.extend MultiTenant::ControllerExtensions
end
