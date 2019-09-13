module ActiveRecordDistributeStatementsStructure
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'activerecord-multi-tenant/tasks/db.rake'
    end
  end
end
