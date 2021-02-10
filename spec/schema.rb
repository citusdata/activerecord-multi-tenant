# Resets the database, except when we are only running a specific spec
ARGV.grep(/\w+_spec\.rb/).empty? && ActiveRecord::Schema.define(version: 1) do
  enable_extension_on_all_nodes 'uuid-ossp'
  enable_extension_on_all_nodes 'pgcrypto'

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

  create_table :subclass_tasks, force: true, partition_key: :non_model_id do |t|
    t.column :non_model_id, :integer
    t.column :name, :string
  end

  create_table :organizations, force: true, id: :uuid do |t|
    t.column :name, :string
  end

  create_table :uuid_records, force: true, partition_key: :organization_id do |t|
    t.column :organization_id, :uuid
    t.column :description, :string
  end

  create_table :categories, force: true do |t|
    t.column :name, :string
  end

  create_table :project_categories, force: true, partition_key: :account_id do |t|
    t.column :name, :string
    t.column :account_id, :integer
    t.column :project_id, :integer
    t.column :category_id, :integer
  end

  create_table :allowed_places, force: true, id: false do |t|
    t.string :account_id, :integer
    t.string :name, :string
  end

  create_table :domains, force: true, partition_key: :account_id do |t|
    t.column :account_id, :integer
    t.column :name, :string
    t.column :deleted, :boolean, default: false
  end

  create_table :pages, force: true, partition_key: :account_id do |t|
    t.column :account_id, :integer
    t.column :name, :string
    t.column :domain_id, :integer
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
  create_distributed_table :subclass_tasks, :non_model_id
  create_distributed_table :uuid_records, :organization_id
  create_distributed_table :project_categories, :account_id
  create_distributed_table :allowed_places, :account_id
  create_distributed_table :domains, :account_id
  create_distributed_table :pages, :account_id
  create_reference_table :categories
end

class Account < ActiveRecord::Base
  multi_tenant :account
  has_many :projects
  has_one :manager, inverse_of: :account
end

class Project < ActiveRecord::Base
  multi_tenant :account
  has_one :manager
  has_many :tasks
  has_many :sub_tasks, through: :tasks

  has_many :project_categories
  has_many :categories, through: :project_categories

  validates_uniqueness_of :name, scope: [:account]
end

class Manager < ActiveRecord::Base
  multi_tenant :account
  belongs_to :project
end

class Task < ActiveRecord::Base
  multi_tenant :account
  belongs_to :project
  has_many :sub_tasks

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

  validates_uniqueness_of :name, scope: [:account]
end

class PartitionKeyNotModelTask < ActiveRecord::Base
  multi_tenant :non_model
end

class AbstractTask < ActiveRecord::Base
  self.abstract_class = true
  multi_tenant :non_model
end

class SubclassTask < AbstractTask
end

class Comment < ActiveRecord::Base
  multi_tenant :account
  belongs_to :commentable, polymorphic: true
  belongs_to :task, -> { where(comments: { commentable_type: 'Task'  }) }, foreign_key: 'commentable_id'
end

class Organization < ActiveRecord::Base
  has_many :uuid_records
end

class UuidRecord < ActiveRecord::Base
  multi_tenant :organization
end

class Category < ActiveRecord::Base
  has_many  :project_categories
  has_many :projects, through: :project_categories
end

class ProjectCategory < ActiveRecord::Base
  multi_tenant :account
  belongs_to :project
  belongs_to :category
  belongs_to :account
end

class AllowedPlace < ActiveRecord::Base
  multi_tenant :account
end

class Domain < ActiveRecord::Base
  multi_tenant :account
  has_many :pages
  default_scope { where(deleted: false) }
end

class Page < ActiveRecord::Base
  multi_tenant :account
  belongs_to :domain
end
