false && ActiveRecord::Schema.define(version: 1) do
  create_table :accounts, force: true do |t|
    t.column :name, :string
    t.column :subdomain, :string
    t.column :domain, :string
  end

  create_table :projects, force: true, partition_key: :account_id do |t|
    t.column :name, :string
    t.column :account_id, :integer
  end

  create_table :managers, force: true, partition_key: :account_id do |t|
    t.column :name, :string
    t.column :project_id, :integer
    t.column :account_id, :integer
  end

  create_table :tasks, force: true, partition_key: :account_id do |t|
    t.column :name, :string
    t.column :account_id, :integer
    t.column :project_id, :integer
    t.column :completed, :boolean
  end

  create_table :countries, force: true do |t|
    t.column :name, :string
  end

  create_table :unscoped_models, force: true do |t|
    t.column :name, :string
  end

  create_table :aliased_tasks, force: true, partition_key: :account_id do |t|
    t.column :name, :string
    t.column :project_alias_id, :integer
    t.column :account_id, :integer
  end

  create_table :custom_partition_key_tasks, force: true, partition_key: :accountID do |t|
    t.column :name, :string
    t.column :accountID, :integer
  end

  create_table :comments, force: true, partition_key: :account_id do |t|
    t.column :commentable_id, :integer
    t.column :commentable_type, :string
    t.column :account_id, :integer
  end

  create_distributed_table :accounts, :id
  create_distributed_table :projects, :account_id
  create_distributed_table :managers, :account_id
  create_distributed_table :tasks, :account_id
  create_distributed_table :aliased_tasks, :account_id
  create_distributed_table :custom_partition_key_tasks, :accountID
  create_distributed_table :comments, :account_id
end

class Account < ActiveRecord::Base
  multi_tenant :account
  has_many :projects
end

class Project < ActiveRecord::Base
  multi_tenant :account
  has_one :manager
  has_many :tasks

  validates_uniqueness_of :name, scope: [:account]
end

class Manager < ActiveRecord::Base
  multi_tenant :account
  belongs_to :project
end

class Task < ActiveRecord::Base
  multi_tenant :account
  belongs_to :project
  default_scope -> { where(completed: nil).order('name') }

  validates_uniqueness_of :name
end

class UnscopedModel < ActiveRecord::Base
  validates_uniqueness_of :name
end

class AliasedTask < ActiveRecord::Base
  multi_tenant :account
  belongs_to :project_alias, class_name: 'Project'
end

class CustomPartitionKeyTask < ActiveRecord::Base
  multi_tenant :account, partition_key: 'accountID'
  validates_uniqueness_of :name, scope: [:account]
end

class Comment < ActiveRecord::Base
  multi_tenant :account
  belongs_to :commentable, polymorphic: true
  belongs_to :task, -> { where(comments: { commentable_type: 'Task'  }) }, foreign_key: 'commentable_id'
end
