# frozen_string_literal: true

module ActiveRecord
  module Associations
    module ClassMethods
      # rubocop:disable Naming/PredicateName
      def has_and_belongs_to_many_with_tenant(name, options = {}, &extension)
        # rubocop:enable Naming/PredicateName
        has_and_belongs_to_many_without_tenant(name, **options, &extension)

        middle_reflection = _reflections[name.to_s].through_reflection
        join_model = middle_reflection.klass

        # get tenant_enabled from options and if it is not set, set it to false
        tenant_enabled = options[:tenant_enabled] || false

        return unless tenant_enabled

        tenant_class_name = options[:tenant_class_name]
        tenant_column = options[:tenant_column]

        match = tenant_column.match(/(\w+)_id/)
        tenant_field_name = match[1] if match

        join_model.class_eval do
          belongs_to tenant_field_name.to_sym, class_name: tenant_class_name
          before_create :tenant_set

          private

          define_method :tenant_set do
            # puts "Class: #{self.class}"
            # puts "MultiTenant.current_tenant_id: #{MultiTenant.current_tenant_id}"
            # puts "Tenant column: #{options[:tenant_column]}"
            # puts "Middle reflection: #{middle_reflection.name}"
            # puts "Join model: #{join_model}"
            # puts "Join model Left: #{join_model.left_model}"
            #
            # # self.instance_variables.each do |var|
            # #   puts "#{var}: #{self.instance_variable_get(var)}"
            # # end
            # #
            # join_object.methods.each do |method|
            #   puts "Method: #{method}"
            # end
            #
            # self.class.constants.each do |constant|
            #   puts "Constant: #{constant}, Value: #{self.class.const_get(constant)}"
            # end
            if tenant_enabled
              raise MultiTenant::MissingTenantError, 'Tenant Id is not set' unless MultiTenant.current_tenant_id

              send("#{tenant_column}=", MultiTenant.current_tenant_id)
            end
          end
        end
      end

      alias has_and_belongs_to_many_without_tenant has_and_belongs_to_many
      alias has_and_belongs_to_many has_and_belongs_to_many_with_tenant
    end
  end
end
