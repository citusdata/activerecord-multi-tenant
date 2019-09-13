require "active_record"


Rake::Task["db:structure:dump"].enhance do
  return unless ActiveRecord::SchemaDumper.include_distribute_statements

  if ActiveRecord::VERSION::MAJOR >= 6
    databases = ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml
  else
    databases = [ActiveRecord::Tasks::DatabaseTasks.current_config]
  end

  query_distributed = 'SELECT logicalrelid, pg_attribute.attname ' \
                      'FROM pg_dist_partition ' \
                      'INNER JOIN pg_attribute ON (logicalrelid=attrelid) ' \
                      'WHERE partmethod=\'h\' ' \
                      'AND attnum=substring(partkey from \'%:varattno #"[0-9]+#"%\' for \'#\')::int;'


  query_reference = "SELECT logicalrelid FROM pg_dist_partition WHERE partmethod = 'n';"

  databases.each do |db_config|
    # for versions before 6.0, there will only be 1 database in the list
    connection = ActiveRecord::Base.establish_connection(db_config)
    filenames = []
    if ActiveRecord::VERSION::MAJOR >= 6
      Rails.application.config.paths['db'].each do |path|
        filenames << File.join(path, db_config.spec_name + '_structure.sql')
      end
    end

    unless filenames.present?
      Rails.application.config.paths['db'].each do |path|
        filenames << File.join(path, 'structure.sql')
      end
    end

    schema = ''
    begin
      distributed_tables = connection.connection.execute(query_distributed)
      reference_tables = connection.connection.execute(query_reference)
    rescue
      # citus is not installed, failing because pg_dist_partition not found
    else
      distributed_tables.values.each do |distributed_table|
        schema <<  "SELECT create_distributed_table('%s', '%s');\n" % [distributed_table[0], distributed_table[1]]
      end

      reference_tables.values.each do |reference_table|
        schema <<  "SELECT create_reference_table('%s');\n" % [reference_table[0]]
      end
    end

    filenames.each do |filename|
      File.open(filename, "a") { |f| f.puts schema }
    end
    puts "Added distribute statements to #{filenames}"
  end

end
