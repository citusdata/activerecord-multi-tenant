Rake::Task["db:structure:dump"].enhance do
  printf('coucou')
  filenames = []
  filenames << ENV['DB_STRUCTURE'] if ENV.key?('DB_STRUCTURE')


  if ActiveRecord::VERSION::MAJOR >= 6
    # Based on https://github.com/rails/rails/pull/36560/files
    databases = ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |spec_name|
      Rails.application.config.paths['db'].each do |path|
        filenames << File.join(path, spec_name + '_structure.sql')
      end
    end
  end

  unless filenames.present?
    Rails.application.config.paths['db'].each do |path|
      filenames << File.join(path, 'structure.sql')
    end
  end


  query_distributed = "SELECT logicalrelid, pg_attribute.attname" \
                      "FROM pg_dist_partition" \
                      "INNER JOIN pg_attribute ON (logicalrelid=attrelid)" \
                      "WHERE logicalrelid::varchar(255) = '{}'" \
                      "AND partmethod='h'" \
                      "AND attnum=substring(partkey from '%:varattno #\"[0-9]+#\"%' for '#')::int"

  query_reference = "SELECT logicalrelid FROM pg_dist_partition WHERE partmethod = 'n';"

  connection = ActiveRecord::Base.establish_connection(database_urls.first)
  distributed_tables = connection.execute(query_distributed)
  reference_tables = connection.execute(query_reference)

  schema = ''

  distributed_tables.values.each do |distributed_table|
    schema <<  "SELECT create_distributed_table(%s, %s);\n" % [distributed_table[0], distributed_table[1]]
  end

  reference_tables.values.each do |reference_table|
    schema <<  "SELECT create_reference_table(%s);\n" % [reference_table[0]]
  end


  filenames.each do |file|
    File.open(file, "w") { |f| f.puts schema }
    puts "Added distribute statements to #{file}"
  end

end
