# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'activerecord-multi-tenant/version'

Gem::Specification.new do |spec|
  spec.name = 'activerecord-multi-tenant'
  spec.version = MultiTenant::VERSION
  spec.summary = 'ActiveRecord/Rails integration for multi-tenant databases, ' \
                 'in particular the Citus extension for PostgreSQL'
  spec.description = ''
  spec.authors = ['Citus Data']
  spec.email = 'engage@citusdata.com'
  spec.required_ruby_version = '>= 3.0.0'
  spec.metadata = { 'rubygems_mfa_required' => 'true' }

  spec.files = `git ls-files`.split("\n")
  spec.require_paths = ['lib']
  spec.homepage = 'https://github.com/citusdata/activerecord-multi-tenant'
  spec.license = 'MIT'

  spec.add_dependency 'rails', '>= 6'

  spec.add_development_dependency 'anbt-sql-formatter'
  spec.add_development_dependency 'codecov'
  spec.add_development_dependency 'pg'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.0'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'sidekiq'

  spec.add_development_dependency 'thor'
end
