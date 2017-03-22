# Resets the database, except when we are only running a specific spec
ARGV.grep(/\w+_spec\.rb/).empty? && ActiveRecord::Schema.define(version: 1) do
  create_table :accounts, force: true do |t|
    t.column :name, :string
    t.column :subdomain, :string
    t.column :domain, :string
  end

  create_table :projects, force: true, partition_key: :account_id do |t|
    t.column :account_id, :integer
    t.column :name, :string
  end

  create_table :managers, force: true, partition_key: :account_id do |t|
    t.column :account_id, :integer
    t.column :name, :string
    t.column :project_id, :integer
  end

  create_table :tasks, force: true, partition_key: :account_id do |t|
    t.column :name, :string
    t.column :account_id, :integer
    t.column :project_id, :integer
    t.column :completed, :boolean
  end

  create_table :sub_tasks, force: true, partition_key: :account_id do |t|
    t.column :account_id, :integer
    t.column :name, :string
    t.column :task_id, :integer
    t.column :type, :string
  end

  create_table :countries, force: true do |t|
    t.column :name, :string
  end

  create_table :unscoped_models, force: true do |t|
    t.column :name, :string
  end

  create_table :aliased_tasks, force: true, partition_key: :account_id do |t|
    t.column :account_id, :integer
    t.column :name, :string
    t.column :project_alias_id, :integer
  end

  create_table :custom_partition_key_tasks, force: true, partition_key: :accountID do |t|
    t.column :accountID, :integer
    t.column :name, :string
  end

  create_table :comments, force: true, partition_key: :account_id do |t|
    t.column :account_id, :integer
    t.column :commentable_id, :integer
    t.column :commentable_type, :string
  end

  create_table :partition_key_not_model_tasks, force: true, partition_key: :non_model_id do |t|
    t.column :non_model_id, :integer
    t.column :name, :string
  end

  create_distributed_table :accounts, :id
  create_distributed_table :projects, :account_id
  create_distributed_table :managers, :account_id
  create_distributed_table :tasks, :account_id
  create_distributed_table :sub_tasks, :account_id
  create_distributed_table :aliased_tasks, :account_id
  create_distributed_table :custom_partition_key_tasks, :accountID
  create_distributed_table :comments, :account_id
  create_distributed_table :partition_key_not_model_tasks, :non_model_id
end

class Account < ActiveRecord::Base
  multi_tenant :account
  has_many :projects
end

class Project < ActiveRecord::Base
  multi_tenant :account
  has_one :manager
  has_many :tasks
  has_many :sub_tasks, through: :tasks

  if Rails::VERSION::MAJOR < 4
    validates_uniqueness_of :name, scope: [:account_id]
  else
    validates_uniqueness_of :name, scope: [:account]
  end
end

class Manager < ActiveRecord::Base
  multi_tenant :account
  belongs_to :project
end

class Task < ActiveRecord::Base
  multi_tenant :account
  belongs_to :project
  has_many :sub_tasks

  default_scope -> { where(completed: nil).order('name') }

  validates_uniqueness_of :name
end

class SubTask < ActiveRecord::Base
  multi_tenant :account
  belongs_to :task
  has_one :project, through: :task
end

class StiSubTask < SubTask
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

  if Rails::VERSION::MAJOR < 4
    validates_uniqueness_of :name, scope: [:accountID]
  else
    validates_uniqueness_of :name, scope: [:account]
  end
end

class PartitionKeyNotModelTask < ActiveRecord::Base
  multi_tenant :non_model
end

class Comment < ActiveRecord::Base
  multi_tenant :account
  belongs_to :commentable, polymorphic: true

  if Rails::VERSION::MAJOR >= 4
    belongs_to :task, -> { where(comments: { commentable_type: 'Task'  }) }, foreign_key: 'commentable_id'
  end
end
