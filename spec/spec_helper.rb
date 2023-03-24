$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'active_record/railtie'
require 'action_controller/railtie'
require 'rspec/rails'

require 'activerecord-multi-tenant'

require 'bundler'
Bundler.require(:default, :development)

require 'simplecov'
SimpleCov.start

require 'codecov'
SimpleCov.formatter = SimpleCov::Formatter::Codecov

dbconfig = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'database.yml')))
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
ActiveRecord::Base.establish_connection(dbconfig['test'])

RSpec.configure do |config|
  config.infer_base_class_for_anonymous_controllers = true
  config.use_transactional_fixtures = false
  config.filter_run_excluding type: :controller unless Object.const_defined?(:ActionController)

  config.after(:each) do
    MultiTenant.current_tenant = nil
  end

  config.before(:suite) do
    MultiTenant::FastTruncate.run

    # Keep this here until https://github.com/citusdata/citus/issues/1236 is fixed
    MultiTenant.enable_with_lock_workaround
  end

  config.after(:each) do
    MultiTenant::FastTruncate.run
  end
end

module MultiTenantTest
  class Application < Rails::Application; end
end

MultiTenantTest::Application.config.secret_token = 'x' * 40
MultiTenantTest::Application.config.secret_key_base = 'y' * 40

def uses_prepared_statements?
  ActiveRecord::Base.connection.prepared_statements
end

def with_belongs_to_required_by_default(&block)
  default_value = ActiveRecord::Base.belongs_to_required_by_default
  ActiveRecord::Base.belongs_to_required_by_default = true
  yield
ensure
  ActiveRecord::Base.belongs_to_required_by_default = default_value
end
require 'schema'
