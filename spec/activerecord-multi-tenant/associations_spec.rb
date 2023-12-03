# frozen_string_literal: true

require 'spec_helper'

describe MultiTenant, 'Association methods' do
  let(:account1) { Account.create! name: 'test1' }
  let(:account2) { Account.create! name: 'test2' }
  let(:project1) { Project.create! name: 'something1', account: account1 }
  let(:project2) { Project.create! name: 'something2', account: account2, id: project1.id }

  let(:task1) { Task.create! name: 'task1', project: project1, account: account1 }
  let(:task2) { Task.create! name: 'task2', project: project2, account: account2, id: task1.id }
  let(:manager1) { Manager.create! name: 'manager1', account: account1, tasks: [task1] }
  let(:project3) { Project.create! name: 'something3', account: account1, managers: [manager1] }

  context 'include the tenant_id in queries and' do
    it 'creates a task with correct account_id' do
      expect(project2.tasks.create(name: 'task3').account_id).to eq(account2.id)
    end
    it 'return correct account_id' do
      expect(task1.project.account_id).to_not eq(task2.project.account_id) # belongs_to
      expect(project2.tasks.count).to eq(1)
      expect(project2.tasks.first.account_id).to eq(account2.id) # has_many
    end

    it 'check has_many_belongs_to' do
      MultiTenant.with(account1) do
        expect(manager1.tasks.first.account_id).to eq(task1.account_id) # has_many
      end
    end

    it 'check has_many_belongs_to without tenant in the intermediate table' do
      MultiTenant.with(account1) do
        expect(manager1.tasks.first.account_id).to eq(task1.account_id) # has_many
      end
    end

    it 'check has_many_belongs_to tenant_enabled false' do
      MultiTenant.with(account1) do
        expect(project3.managers.first.id).to eq(manager1.id) # has_many
      end
    end
  end
end
