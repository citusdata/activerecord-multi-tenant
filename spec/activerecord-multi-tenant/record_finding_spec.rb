require 'spec_helper'

describe MultiTenant, 'Record finding' do
  it 'searches for tenant object using the scope' do
    account = Account.create! name: 'test'
    project = account.projects.create! name: 'something'
    MultiTenant.with(account) do
      expect(Project.find(project.id)).to be_present
    end
  end

  it 'supports UUIDs' do
    organization = Organization.create! name: 'test'
    uuid_record = organization.uuid_records.create! description: 'something'
    MultiTenant.with(organization) do
      expect(UuidRecord.find(uuid_record.id)).to be_present
    end
  end

  it 'can use find_bys accurately' do
    first_tenant = Account.create! name: 'First Tenant'
    second_tenant = Account.create! name: 'Second Tenant'
    first_record = first_tenant.projects.create! name: 'identical name'
    second_record = second_tenant.projects.create! name: 'identical name'
    MultiTenant.with(first_tenant) do
      found_record = Project.find_by(name: 'identical name')
      expect(found_record).to eq(first_record)
    end
    MultiTenant.with(second_tenant) do
      found_record = Project.find_by(name: 'identical name')
      expect(found_record).to eq(second_record)
    end
  end
end
