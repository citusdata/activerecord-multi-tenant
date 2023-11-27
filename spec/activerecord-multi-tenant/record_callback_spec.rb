# frozen_string_literal: true

require 'spec_helper'

class ProjectWithCallbacks < ActiveRecord::Base
  self.table_name = :projects

  multi_tenant :account

  after_update do |record|
    # Ensure that we don't have TenantIdWrapper here
    record.account.name = 'callback'
    record.account.save!
  end
end

describe MultiTenant, 'Callbacks' do
  let(:account) { Account.create! name: 'test' }
  let(:project) { ProjectWithCallbacks.create! account: account, name: 'something' }

  it 'takes callbacks into account' do
    project.name = 'something else'
    project.save!
    expect(account.reload.name).to eq 'callback'
  end
end
