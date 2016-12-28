require 'spec_helper'

describe MultiTenant, 'Record modifications' do
  let(:tenant) { Tenant.create! name: 'test' }
  let(:obj) { tenant.tenant_objects.create! title: 'something' }

  it 'includes the tenant_id in UPDATEs' do
    obj.update! title: 'something else'
    MultiTenant.with(tenant) do
      expect(TenantObject.find(obj.id).title).to eq 'something else'
    end
  end

  it 'includes the tenant_id in DELETEs' do
    obj.destroy!
    MultiTenant.with(tenant) do
      expect(TenantObject.find_by(id: obj.id)).not_to be_present
    end
  end
end
