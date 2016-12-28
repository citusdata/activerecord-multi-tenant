Gem::Specification.new do |s|
  s.name        = 'activerecord-multi-tenant'
  s.version     = '0.2.0'
  s.date        = Date.today
  s.summary     = "ActiveRecord/Rails integration for multi-tenant databases, in particular the Citus extension for PostgreSQL"
  s.description = ""
  s.authors     = ["Citus Data"]
  s.email       = 'engage@citusdata.com'
  s.files       = ['lib/activerecord-multi-tenant.rb',
                   'lib/activerecord-multi-tenant/copy_from_client.rb',
                   'lib/activerecord-multi-tenant/default_scope.rb',
                   'lib/activerecord-multi-tenant/migrations.rb',
                   'lib/activerecord-multi-tenant/multi_tenant.rb',
                   'lib/activerecord-multi-tenant/referential_integrity.rb',
                   'lib/activerecord-multi-tenant/version.rb']
  s.homepage    = 'https://github.com/citusdata/activerecord-multi-tenant'
  s.license     = 'MIT'

  s.add_runtime_dependency 'acts_as_tenant'

  s.add_development_dependency 'rspec', '>= 3.0'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'database_cleaner', '~> 1.3.0'
  s.add_development_dependency 'pg'
end
