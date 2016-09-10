class ActiveRecord::Base
  def self.acts_as_distributed(partition_column:)
    check_citus_compatibility
    @partition_column = partition_column
  end

  def partition_column
    @partition_column
  end

  private

  def self.check_citus_compatibility
    if primary_keys && primary_keys.include?('id')
      suggested_name = name.underscore + '_id'
      fail format("citus-rails currently does not support models with 'id' as one of multiple primary keys - please name your id column '%s'", suggested_name)
    end
  end
end
