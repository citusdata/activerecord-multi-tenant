# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

# Codecov is enabled when CI is set to true
if ENV['CI'] == 'true'
  puts 'Enabling Simplecov to upload code coverage results to codecov.io'
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/test/' # Exclude test directory from coverage
    add_filter '/spec/' # Exclude spec directory from coverage
    add_filter '/config/' # Exclude config directory from coverage

    # Add any additional filters or exclusions if needed
    # add_filter '/other_directory/'

    add_group 'Lib', '/lib' # Include the lib directory for coverage
    puts "Tracked files: #{SimpleCov.tracked_files}"
  end
  SimpleCov.minimum_coverage 80

  require 'simplecov-cobertura'
  SimpleCov.formatter = SimpleCov::Formatter::CoberturaFormatter
end

require 'active_record/railtie'
require 'action_controller/railtie'
require 'rspec/rails'

module MultiTenantTest
  class Application < Rails::Application; end
end

# Specifies columns which shouldn't be exposed while calling #inspect.
ActiveSupport.on_load(:active_record) do
  self.filter_attributes += MultiTenantTest::Application.config.filter_parameters
end

require 'activerecord_multi_tenant'

# It's necessary for testing the filtering of senstive column values in ActiveRecord.
# Refer to "describe 'inspect method filters senstive column values'"
#
# To verify that ActiveSupport.on_load(:active_record) is not being unnecessarily invoked,
# this line should be placed after "require 'activerecord_multi_tenant'" and before ActiveRecord::Base is called.
MultiTenantTest::Application.config.filter_parameters = [:password]

require 'bundler'
Bundler.require(:default, :development)
require_relative 'support/format_sql'

dbconfig = YAML.safe_load_file(File.join(File.dirname(__FILE__), 'database.yml'))
ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), 'debug.log'))
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
  end

  config.after(:each) do
    MultiTenant::FastTruncate.run
  end
end

# rubocop:disable Lint/UnusedMethodArgument
# changing the name of the parameter breaks tests
def with_belongs_to_required_by_default(&block)
  default_value = ActiveRecord::Base.belongs_to_required_by_default
  ActiveRecord::Base.belongs_to_required_by_default = true
  yield
ensure
  ActiveRecord::Base.belongs_to_required_by_default = default_value
end
# rubocop:enable Lint/UnusedMethodArgument
require 'schema'
