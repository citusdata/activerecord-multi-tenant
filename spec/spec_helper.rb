$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'active_record/railtie'
require 'action_controller/railtie'
require 'rspec/rails'
require 'database_cleaner'

require 'activerecord-multi-tenant'

dbconfig = YAML::load(IO.read(File.join(File.dirname(__FILE__), 'database.yml')))
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), "debug.log"))
ActiveRecord::Base.establish_connection(dbconfig['test'])

RSpec.configure do |config|
  config.infer_base_class_for_anonymous_controllers = true
  config.use_transactional_fixtures = false

  config.after(:each) do
    MultiTenant.current_tenant = nil
  end

  config.before(:suite) do
    DatabaseCleaner[:active_record].strategy = :truncation
    DatabaseCleaner[:active_record].clean

    # Keep this here until https://github.com/citusdata/citus/issues/1236 is fixed in a patch release we can run tests with
    MultiTenant.enable_with_lock_workaround
  end

  config.before(:each) do
    DatabaseCleaner[:active_record].start
  end

  config.after(:each) do
    DatabaseCleaner[:active_record].clean
  end
end

module MultiTenantTest
  class Application < Rails::Application; end
end

MultiTenantTest::Application.config.secret_token = 'x' * 40
MultiTenantTest::Application.config.secret_key_base = 'y' * 40

require 'schema'
