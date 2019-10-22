require 'spec_helper'
require 'rake'


describe 'Schema Dumper enhancement' do
  let(:file_like_object) { double("file like object") }

  it 'should list distributed tables' do
    distributed_tables  = ActiveRecord::SchemaDumper.get_distributed_tables(ActiveRecord::Base.connection)

    distributed_result = [["accounts", "id"],
                          ["projects", "account_id"],
                          ["managers", "account_id"],
                          ["tasks", "account_id"],
                          ["sub_tasks", "account_id"],
                          ["aliased_tasks", "account_id"],
                          ["custom_partition_key_tasks", "accountID"],
                          ["comments", "account_id"],
                          ["partition_key_not_model_tasks", "non_model_id"],
                          ["subclass_tasks", "non_model_id"],
                          ["uuid_records", "organization_id"],
                          ["allowed_places", "account_id"],
                          ["project_categories", "account_id"]]

    expect(distributed_tables.to_set).to eq(distributed_result.to_set)
  end

  it 'should list reference tables' do
    reference_tables = ActiveRecord::SchemaDumper.get_reference_tables(ActiveRecord::Base.connection)
    reference_result = [["categories"]]
    expect(reference_tables.to_set).to eq(reference_result.to_set)
  end

  it 'distribute statements' do
    distributed_statements = ActiveRecord::SchemaDumper.get_distribute_statements(ActiveRecord::Base.connection)
    expect(distributed_statements).to eq("SELECT create_distributed_table('accounts', 'id');\nSELECT create_distributed_table('projects', 'account_id');\nSELECT create_distributed_table('managers', 'account_id');\nSELECT create_distributed_table('tasks', 'account_id');\nSELECT create_distributed_table('sub_tasks', 'account_id');\nSELECT create_distributed_table('aliased_tasks', 'account_id');\nSELECT create_distributed_table('custom_partition_key_tasks', 'accountID');\nSELECT create_distributed_table('comments', 'account_id');\nSELECT create_distributed_table('partition_key_not_model_tasks', 'non_model_id');\nSELECT create_distributed_table('subclass_tasks', 'non_model_id');\nSELECT create_distributed_table('uuid_records', 'organization_id');\nSELECT create_distributed_table('project_categories', 'account_id');\nSELECT create_distributed_table('allowed_places', 'account_id');\n")
  end

  it 'reference tables statements' do
    distributed_statements = ActiveRecord::SchemaDumper.get_distribute_statements(ActiveRecord::Base.connection, reference=true)
    expect(distributed_statements).to eq("SELECT create_reference_table('categories');\n")
  end

  it 'no distributed tables' do
    ActiveRecord::SchemaDumper.stub(:get_distributed_tables).with(anything()) {[]}
    distributed_statements = ActiveRecord::SchemaDumper.get_distribute_statements(ActiveRecord::Base.connection)
    expect(distributed_statements).to eq("")
  end

  it 'no citus metadata tables' do
    ActiveRecord::SchemaDumper.stub(:get_distributed_tables).with(anything()) {nil}
    distributed_statements = ActiveRecord::SchemaDumper.get_distribute_statements(ActiveRecord::Base.connection)
    expect(distributed_statements).to eq(nil)
  end

  it 'no reference tables' do
    ActiveRecord::SchemaDumper.stub(:get_reference_tables).with(anything()) {[]}
    distributed_statements = ActiveRecord::SchemaDumper.get_distribute_statements(ActiveRecord::Base.connection, reference=true)
    expect(distributed_statements).to eq("")

  end

  it 'no citus metadata tables for reference' do
    ActiveRecord::SchemaDumper.stub(:get_reference_tables).with(anything()) {nil}
    distributed_statements = ActiveRecord::SchemaDumper.get_distribute_statements(ActiveRecord::Base.connection, reference=true)
    expect(distributed_statements).to eq(nil)
  end


  it 'full statements' do
    distributed_statements = ActiveRecord::SchemaDumper.get_full_distribute_statements(ActiveRecord::Base.connection)
    expect(distributed_statements).to eq("SELECT create_distributed_table('accounts', 'id');\nSELECT create_distributed_table('projects', 'account_id');\nSELECT create_distributed_table('managers', 'account_id');\nSELECT create_distributed_table('tasks', 'account_id');\nSELECT create_distributed_table('sub_tasks', 'account_id');\nSELECT create_distributed_table('aliased_tasks', 'account_id');\nSELECT create_distributed_table('custom_partition_key_tasks', 'accountID');\nSELECT create_distributed_table('comments', 'account_id');\nSELECT create_distributed_table('partition_key_not_model_tasks', 'non_model_id');\nSELECT create_distributed_table('subclass_tasks', 'non_model_id');\nSELECT create_distributed_table('uuid_records', 'organization_id');\nSELECT create_distributed_table('project_categories', 'account_id');\nSELECT create_distributed_table('allowed_places', 'account_id');\nSELECT create_reference_table('categories');\n")

  end

  it 'full statements no reference' do
    ActiveRecord::SchemaDumper.stub(:get_reference_tables).with(anything()) {[]}
    distributed_statements = ActiveRecord::SchemaDumper.get_full_distribute_statements(ActiveRecord::Base.connection)
    expect(distributed_statements).to eq("SELECT create_distributed_table('accounts', 'id');\nSELECT create_distributed_table('projects', 'account_id');\nSELECT create_distributed_table('managers', 'account_id');\nSELECT create_distributed_table('tasks', 'account_id');\nSELECT create_distributed_table('sub_tasks', 'account_id');\nSELECT create_distributed_table('aliased_tasks', 'account_id');\nSELECT create_distributed_table('custom_partition_key_tasks', 'accountID');\nSELECT create_distributed_table('comments', 'account_id');\nSELECT create_distributed_table('partition_key_not_model_tasks', 'non_model_id');\nSELECT create_distributed_table('subclass_tasks', 'non_model_id');\nSELECT create_distributed_table('uuid_records', 'organization_id');\nSELECT create_distributed_table('project_categories', 'account_id');\nSELECT create_distributed_table('allowed_places', 'account_id');\n")
  end

  it 'full statements no distributed' do
    ActiveRecord::SchemaDumper.stub(:get_distributed_tables).with(anything()) {nil}
    distributed_statements = ActiveRecord::SchemaDumper.get_full_distribute_statements(ActiveRecord::Base.connection)
    expect(distributed_statements).to eq("SELECT create_reference_table('categories');\n")
  end

  it 'full statements no citus' do
    ActiveRecord::SchemaDumper.stub(:get_distributed_tables).with(anything()) {nil}
    ActiveRecord::SchemaDumper.stub(:get_reference_tables).with(anything()) {nil}

    distributed_statements = ActiveRecord::SchemaDumper.get_full_distribute_statements(ActiveRecord::Base.connection)
    expect(distributed_statements).to eq("")

  end
end
