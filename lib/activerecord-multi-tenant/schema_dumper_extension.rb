module MultiTenant
  module SchemaDumperExtension
    cattr_accessor :include_distribute_statements, default: true


  end
end

if defined?(ActiveRecord::SchemaDumper)
  ActiveRecord::SchemaDumper.extend(MultiTenant::SchemaDumperExtension)
end
