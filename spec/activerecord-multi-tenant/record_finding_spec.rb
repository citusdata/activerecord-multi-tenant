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

  it 'can use find accurately' do
    first_tenant = Account.create! name: 'First Tenant'
    second_tenant = Account.create! name: 'Second Tenant'
    first_record = first_tenant.projects.create!
    second_record = second_tenant.projects.create!

    MultiTenant.with(first_tenant) do
      found_record = Project.find(first_record.id)
      expect(found_record).to eq(first_record)
      expect { Project.find(second_record.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    MultiTenant.with(second_tenant) do
      found_record = Project.find(second_record.id)
      expect(found_record).to eq(second_record)
      expect { Project.find(first_record.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    MultiTenant.without do
      first_found = Project.find(first_record.id)
      expect(first_found).to eq(first_record)
      second_found = Project.find(second_record.id)
      expect(second_found).to eq(second_record)
    end
  end
end
