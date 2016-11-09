require 'acts_as_tenant'

# Note that the actual details here are subject to change, and you should avoid
# calling acts_as_tenant methods directly as a user of this library
module ActsAsDistributed
  module ModelExtensions
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def acts_as_distributed(tenant, options = {})
        # Typically we don't need to run on the tenant model itself
        if to_s.underscore.to_sym != tenant
          belongs_to(tenant)
          acts_as_tenant(tenant, options)
        end

        # Workaround for https://github.com/citusdata/citus/issues/687
        if to_s.underscore.to_sym == tenant
          before_create -> { self.id ||= self.class.connection.select_value("SELECT nextval('" + [self.class.table_name, self.class.primary_key, 'seq'].join('_') + "'::regclass)") }
        end
      end
    end
  end

  def self.current_tenant
    ActsAsDistributed.current_tenant
  end

  def self.with(tenant, &block)
    ActsAsTenant.with_tenant(tenant, &block)
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.send(:include, ActsAsDistributed::ModelExtensions)
end
