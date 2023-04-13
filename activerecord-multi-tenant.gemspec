Gem::Specification.new do |spec|
  spec.required_ruby_version = '>= 3.0'
end

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'activerecord-multi-tenant/version'

Gem::Specification.new do |s|
  s.name = 'activerecord-multi-tenant'
  s.version = MultiTenant::VERSION
  s.summary = <<~TEXT
    ActiveRecord/Rails integration for multi-tenant databases
    in particular the Citus extension for PostgreSQL
  TEXT

  s.description = ''
  s.authors = ['Citus Data']
  s.email = 'engage@citusdata.com'

  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- {spec}/*`.split("\n")
  s.require_paths = ['lib']
  s.homepage = 'https://github.com/citusdata/activerecord-multi-tenant'
  s.license = 'MIT'

  s.add_dependency 'rails', '>= 6'

  s.add_development_dependency 'codecov'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '>= 3.0'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'sidekiq'
  s.add_development_dependency 'thor'
end
