require 'spec_helper'

describe MultiTenant, 'Record modifications' do
  let(:account) { Account.create! name: 'test' }
  let(:account2) { Account.create! name: 'test2' }
  let(:project) { Project.create! name: 'something', account: account }
  let(:project2) { Project.create! name: 'something2', account: account2, id: project.id }


  it 'includes the tenant_id in DELETEs when using object.destroy' do
    # two records with same id but different account_id
    # when doing project.destroy it should delete only the current one
    # by adding account_id to the destroy

    expect(project.account).to eq(account)
    expect(project2.account).to eq(account2)
    expect(project.id).to eq(project2.id)

    MultiTenant.without() do
      expect(Project.count).to eq(2)
      project.destroy
      expect(Project.count).to eq(1)
    end

    MultiTenant.with(account) do
      expect(Project.where(id: project.id).first).not_to be_present
    end
    MultiTenant.with(account2) do
      expect(Project.where(id: project2.id).first).to be_present
    end

  end

  it 'includes the tenant_id in DELETEs when using object.delete' do
    # two records with same id but different account_id
    # when project.delete it should delete only the current one
    # by adding account_id to the destroy

    expect(project.account).to eq(account)
    expect(project2.account).to eq(account2)
    expect(project.id).to eq(project2.id)

    MultiTenant.without() do
      expect(Project.count).to eq(2)
      project.delete
      expect(Project.count).to eq(1)
    end

    MultiTenant.with(account) do
      expect(Project.where(id: project.id).first).not_to be_present
    end
    MultiTenant.with(account2) do
      expect(Project.where(id: project2.id).first).to be_present
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
