Gem::Specification.new do |s|
  s.name        = 'citus-rails-4.2'
  s.version     = '0.1.0'
  s.date        = Date.today
  s.summary     = "Citus Rails Integration (Rails 4.2)"
  s.description = ""
  s.authors     = ["Citus Data"]
  s.email       = 'engage@citusdata.com'
  s.files       = `git ls-files -z`.split("\x0")
  s.homepage    = 'https://github.com/citusdata/citus-rails'
  s.license     = 'MIT'

  s.add_runtime_dependency 'activerecord', '~> 4.2'
  s.add_runtime_dependency 'composite_primary_keys', '~> 8.0'
end
