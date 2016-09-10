class ActiveRecord::Associations::BelongsToAssociation
  alias_method :remove_keys_without_cpk, :remove_keys
  def remove_keys
    return remove_keys_without_cpk unless reflection.foreign_key.is_a?(Array)

    fk = reflection.foreign_key - [owner.class.partition_column]
    owner[fk] = nil
  end
end
