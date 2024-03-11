module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaStatements
      alias orig_create_table create_table
      def create_table(table_name, options = {}, &block)
        ret = orig_create_table(table_name, **options.except(:partition_key), &block)
        if options[:id] != false && options[:partition_key] && options[:partition_key].to_s != 'id'
          execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{table_name}_pkey"
          execute "ALTER TABLE #{table_name} ADD PRIMARY KEY(\"#{options[:partition_key]}\", id)"
        end
        ret
      end
    end
  end
end
