$:.push File.expand_path('../lib', __FILE__)
require 'activerecord-multi-tenant/version'

Gem::Specification.new do |s|
  s.name        = 'activerecord-multi-tenant'
  s.version     = MultiTenant::VERSION
  s.summary     = 'ActiveRecord/Rails integration for multi-tenant databases, in particular the Citus extension for PostgreSQL'
  s.description = ''
  s.authors     = ['Citus Data']
  s.email       = 'engage@citusdata.com'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {spec}/*`.split("\n")
  s.require_paths = ['lib']
  s.homepage      = 'https://github.com/citusdata/activerecord-multi-tenant'
  s.license       = 'MIT'

  s.add_runtime_dependency('request_store', '>= 1.0.5')
  s.add_dependency('rails','>= 3.1')

  s.add_development_dependency 'rspec', '>= 3.0'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'database_cleaner', '~> 1.3.0'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'thor'
end
