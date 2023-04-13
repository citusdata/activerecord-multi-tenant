module MultiTenant
  class CopyFromClientHelper
    attr_reader :count

    def initialize(conn, column_types)
      @count = 0
      @conn = conn
      @column_types = column_types
    end

    def <<(row)
      row = row.map.with_index { |val, idx| @column_types[idx].serialize(val) }
      @conn.put_copy_data(row)
      @count += 1
    end
  end

  module CopyFromClient
    def copy_from_client(columns, &block)
      conn = connection.raw_connection
      column_types = columns.map { |c| type_for_attribute(c.to_s) }
      helper = MultiTenant::CopyFromClientHelper.new(conn, column_types)
      conn.copy_data %{COPY #{quoted_table_name}("#{columns.join('","')}") FROM STDIN}, PG::TextEncoder::CopyRow.new do
        block.call helper
      end
      helper.count
    end
  end
end

ActiveSupport.on_load(:active_record) do |base|
  base.extend(MultiTenant::CopyFromClient)
end
