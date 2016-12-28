ActiveRecord::Schema.define(version: 1) do
  create_table :tenants, force: true do |t|
    t.column :name, :string
  end

  create_table :tenant_objects, force: true, partition_key: :tenant_id do |t|
    t.column :title, :string
    t.column :tenant_id, :integer
  end

  create_distributed_table :tenants, :id
  create_distributed_table :tenant_objects, :tenant_id
end

class Tenant < ActiveRecord::Base
  multi_tenant :tenant
  has_many :tenant_objects
end

class TenantObject < ActiveRecord::Base
  multi_tenant :tenant
end
