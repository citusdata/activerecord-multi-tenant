# frozen_string_literal: true

# This module extension is a monkey patch to the ActiveRecord::Associations::ClassMethods module.
# It overrides the has_and_belongs_to_many method to add the tenant_id to the join table if the
# tenant_enabled option is set to true.

module ActiveRecord
  module Associations
    module ClassMethods
      # rubocop:disable Naming/PredicateName
      def has_and_belongs_to_many_with_tenant(name, scope = nil, **options, &extension)
        # rubocop:enable Naming/PredicateName
        has_and_belongs_to_many_without_tenant(name, scope, **options, &extension)

        middle_reflection = _reflect_on_association(name.to_s).through_reflection
        join_model = middle_reflection.klass

        # get tenant_enabled from options and if it is not set, set it to false
        tenant_enabled = options[:tenant_enabled] || false

        return unless tenant_enabled

        tenant_class_name = options[:tenant_class_name]
        tenant_column = options[:tenant_column]

        match = tenant_column.match(/(\w+)_id/)
        tenant_field_name = match ? match[1] : 'tenant'

        join_model.class_eval do
          belongs_to tenant_field_name.to_sym, class_name: tenant_class_name
          before_create :tenant_set

          private

          # This method sets the tenant_id on the join table and executes before creation of the join table record.
          define_method :tenant_set do
            return unless tenant_enabled
            raise MultiTenant::MissingTenantError, 'Tenant Id is not set' unless MultiTenant.current_tenant_id

            send("#{tenant_column}=", MultiTenant.current_tenant_id)
          end
        end
      end

      alias has_and_belongs_to_many_without_tenant has_and_belongs_to_many
      alias has_and_belongs_to_many has_and_belongs_to_many_with_tenant
    end
  end
end
