module MultiTenant
  module SchemaDumperExtension
    cattr_accessor :include_distribute_statements, default: true

    def get_distributed_tables(connection)
      query_distributed = 'SELECT logicalrelid, pg_attribute.attname ' \
                          'FROM pg_dist_partition ' \
                          'INNER JOIN pg_attribute ON (logicalrelid=attrelid) ' \
                          'WHERE partmethod=\'h\' ' \
                          'AND attnum=substring(partkey from \'%:varattno #"[0-9]+#"%\' for \'#\')::int ' \
                          'ORDER BY logicalrelid'

      begin
        return connection.execute(query_distributed).values
      rescue; end
    end

    def get_reference_tables(connection)
      query_reference = "SELECT logicalrelid FROM pg_dist_partition WHERE partmethod = 'n' ORDER BY logicalrelid"
      begin
        return connection.execute(query_reference).values
      rescue; end
    end

    def get_distribute_statements(connection, reference=false)
      if reference
        distributed_tables = get_reference_tables(connection)
        query = "SELECT create_reference_table('%s');\n"
      else
        distributed_tables = get_distributed_tables(connection)
        query = "SELECT create_distributed_table('%s', '%s');\n"
      end

      return unless distributed_tables

      schema = ''
      distributed_tables.each do |distributed_table|
        attrs = if reference then [distributed_table[0]] else [distributed_table[0], distributed_table[1]] end
        schema <<  query % attrs
      end

      schema
    end

    def get_full_distribute_statements(connection)
      schema = ActiveRecord::SchemaDumper.get_distribute_statements(connection) || ''
      schema << (ActiveRecord::SchemaDumper.get_distribute_statements(connection,
                                                                      reference=true) || '')

      schema
    end

  end
end

if defined?(ActiveRecord::SchemaDumper)
  ActiveRecord::SchemaDumper.extend(MultiTenant::SchemaDumperExtension)
end
