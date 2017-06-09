require 'spec_helper'

describe MultiTenant, 'Record modifications' do
  let(:account) { Account.create! name: 'test' }
  let(:project) { account.projects.create! name: 'something' }

  it 'includes the tenant_id in DELETEs' do
    project.destroy
    MultiTenant.with(account) do
      expect(Project.where(id: project.id).first).not_to be_present
    end
  end

  it 'includes the tenant_id in UPDATEs' do
    project.name = 'something else'
    project.save!
    MultiTenant.with(account) do
      expect(Project.find(project.id).name).to eq 'something else'
    end
  end
end
