Gem::Specification.new do |s|
  s.name        = 'citus-rails'
  s.version     = '0.1.1'
  s.date        = Date.today
  s.summary     = "Citus Rails Integration"
  s.description = ""
  s.authors     = ["Citus Data"]
  s.email       = 'engage@citusdata.com'
  s.files       = ['lib/citus-rails.rb']
  s.homepage    = 'https://github.com/citusdata/citus-rails'
  s.license     = 'MIT'

  s.add_runtime_dependency 'acts_as_tenant'
end
