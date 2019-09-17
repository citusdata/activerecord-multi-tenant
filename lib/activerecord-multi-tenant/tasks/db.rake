require "active_record"


Rake::Task["db:structure:dump"].enhance do
  next unless ActiveRecord::SchemaDumper.include_distribute_statements

  if ActiveRecord::VERSION::MAJOR >= 6
    databases = ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml
  else
    databases = [ActiveRecord::Tasks::DatabaseTasks.current_config]
  end

  databases.each do |db_config|
    # for versions before 6.0, there will only be 1 database in the list
    connection = ActiveRecord::Base.establish_connection(db_config).connection
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

    schema = ActiveRecord::SchemaDumper.get_full_distribute_statements(connection)

    filenames.each do |filename|
      File.open(filename, "a") { |f| f.puts schema }
    end
    puts "Added distribute statements to #{filenames}"
  end
end
