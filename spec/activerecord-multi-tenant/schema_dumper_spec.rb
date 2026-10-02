# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'

describe 'Schema dumper' do
  def dump_schema
    stream = StringIO.new
    if ActiveRecord.gem_version >= Gem::Version.create('7.2.0')
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, stream)
    else
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    end
    stream.string
  end

  it 'dumps distributed and reference tables' do
    schema = dump_schema

    expect(schema).to include('create_distributed_table("projects", "account_id")')
    expect(schema).to include('create_distributed_table("custom_partition_key_tasks", "accountID")')
    expect(schema).to include('create_reference_table("categories")')
  end

  # strong_migrations (and anything else) may prepend a module to
  # ActiveRecord::SchemaDumper before this gem is loaded. Wrapping the dumper
  # with alias method chaining after that recursed until SystemStackError.
  it 'dumps the schema when SchemaDumper was already extended with Module#prepend' do
    script = <<~RUBY
      require 'logger'
      require 'yaml'
      require 'erb'
      require 'stringio'
      require 'active_record'

      module OtherSchemaDumperExtension
        def initialize(connection, options = {})
          super
        end
      end
      ActiveRecord::SchemaDumper.prepend(OtherSchemaDumperExtension)

      require 'activerecord-multi-tenant'

      config = YAML.safe_load(ERB.new(File.read(ARGV[0])).result)['test']
      ActiveRecord::Base.establish_connection(config)
      stream = StringIO.new
      if ActiveRecord.gem_version >= Gem::Version.create('7.2.0')
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, stream)
      else
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      end
      puts stream.string
    RUBY

    database_yml = File.expand_path('../database.yml', __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__),
                                     '-e', script, database_yml)

    expect(output).not_to include('SystemStackError')
    expect(status).to be_success
    expect(output).to include('create_distributed_table("projects", "account_id")')
  end
end
