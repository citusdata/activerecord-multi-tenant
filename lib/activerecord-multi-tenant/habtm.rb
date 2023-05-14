# frozen_string_literal: true

module ActiveRecord
  module Associations
    module ClassMethods
      def has_and_belongs_to_many_with_tenant(name, options = {}, &extension)
        has_and_belongs_to_many_without_tenant(name, **options, &extension)

        middle_reflection = _reflections[name.to_s].through_reflection
        join_model = middle_reflection.klass
        join_object = join_model

        # get tenant_enabled from options and if it is not set, set it to false
        tenant_enabled = options[:tenant_enabled] || false

        join_model.class_eval do
          puts "Default tenant class: #{MultiTenant.default_tenant_class}"
          belongs_to :tenant, class_name: Account.name
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

              send("#{options[:tenant_column]}=", MultiTenant.current_tenant_id)
            end
          end
        end
      end

      alias has_and_belongs_to_many_without_tenant has_and_belongs_to_many
      alias has_and_belongs_to_many has_and_belongs_to_many_with_tenant
    end
  end
end
