require 'spec_helper'

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
  has_many :tenant_objects
end

class TenantObject < ActiveRecord::Base
  multi_tenant :tenant
end

describe MultiTenant, 'Record update' do
  it 'includes the tenant_id in UPDATEs' do
    tenant = Tenant.create! name: 'test'
    tenant.tenant_objects.create! title: 'something'
    puts tenant.inspect
  end
end
