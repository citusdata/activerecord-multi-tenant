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
  config.after(:each) do
    MultiTenant.current_tenant = nil
  end

  config.before(:suite) do
    DatabaseCleaner[:active_record].strategy = :transaction
    DatabaseCleaner[:active_record].clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner[:active_record].start
  end

  config.after(:each) do
    DatabaseCleaner[:active_record].clean
  end

  config.infer_base_class_for_anonymous_controllers = true
end

module MultiTenantTest
  class Application < Rails::Application; end
end
