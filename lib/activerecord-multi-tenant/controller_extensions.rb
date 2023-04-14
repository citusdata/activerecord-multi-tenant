# frozen_string_literal: true

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

ActiveSupport.on_load(:action_controller) do |base|
  base.extend MultiTenant::ControllerExtensions
end
