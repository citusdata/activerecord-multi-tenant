module MultiTenant
  class CopyFromClientHelper
    attr_reader :count

    def initialize(conn, column_types)
      @count = 0
      @conn = conn
      @column_types = column_types
    end

    def <<(row)
      row = row.map.with_index { |val, idx| @column_types[idx].type_cast_for_database(val) }
      @conn.put_copy_data(row)
      @count += 1
    end
  end

  module CopyFromClient
    def copy_from_client(columns, &block)
      conn         = connection.raw_connection
      column_types = columns.map { |c| columns_hash[c.to_s] }
      helper = MultiTenant::CopyFromClientHelper.new(conn, column_types)
      conn.copy_data %{COPY #{quoted_table_name}("#{columns.join('","')}") FROM STDIN}, PG::TextEncoder::CopyRow.new do
        block.call helper
      end
      helper.count
    end
  end
end

if defined?(ActiveRecord::Base)
  ActiveRecord::Base.extend(MultiTenant::CopyFromClient)
end
