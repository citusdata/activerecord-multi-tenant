require 'spec_helper'

describe MultiTenant, 'Record finding' do
  it 'searches for tenant object using the scope' do
    tenant = Tenant.create! name: 'test'
    obj = tenant.tenant_objects.create! title: 'something'
    MultiTenant.with(tenant) do
      expect(TenantObject.find(obj.id)).to be_present
    end
  end
end
