# frozen_string_literal: true

module MultiTenant
  # Designed to be mixed into an ActiveRecord model to provide
  # a copy_from_client method that allows for efficient bulk insertion of
  # data into a PostgreSQL database using the COPY command
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
      conn         = connection.raw_connection
      column_types = columns.map { |c| type_for_attribute(c.to_s) }
      helper = MultiTenant::CopyFromClientHelper.new(conn, column_types)
      conn.copy_data %{COPY #{quoted_table_name}("#{columns.join('","')}") FROM STDIN}, PG::TextEncoder::CopyRow.new do
        block.call helper
      end
      helper.count
    end
  end
end

# Add copy_from_client to ActiveRecord::Base
ActiveSupport.on_load(:active_record) do |base|
  base.extend(MultiTenant::CopyFromClient)
end
