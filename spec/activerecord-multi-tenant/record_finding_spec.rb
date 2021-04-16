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

  context 'model with has_many relation through multi-tenant model' do
    let(:tenant_1) { Account.create! name: 'Tenant 1' }
    let(:project_1) { tenant_1.projects.create! }

    let(:tenant_2) { Account.create! name: 'Tenant 2' }
    let(:project_2) { tenant_2.projects.create! }

    let(:category) { Category.create! name: 'Category' }

    before do
      ProjectCategory.create! account: tenant_1, name: '1', project: project_1, category: category
      ProjectCategory.create! account: tenant_2, name: '2', project: project_2, category: category
    end

    it 'can get model without creating query cache' do
      MultiTenant.with(tenant_1) do
        found_category = Project.find(project_1.id).categories.to_a.first
        expect(found_category).to eq(category)
      end
    end

    it 'can get model for other tenant' do
      MultiTenant.with(tenant_2) do
        found_category = Project.find(project_2.id).categories.to_a.first
        expect(found_category).to eq(category)
      end
    end

    it 'can get model without current_tenant' do
      MultiTenant.without do
        found_category = Project.find(project_2.id).categories.to_a.first
        expect(found_category).to eq(category)
      end
    end
  end
end
