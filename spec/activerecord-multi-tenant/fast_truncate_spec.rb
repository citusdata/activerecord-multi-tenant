require 'spec_helper'

describe MultiTenant::FastTruncate do
  before(:each) do
    MultiTenant::FastTruncate.run
  end

  it 'truncates tables that have exactly one row inserted' do
    Account.create! name: 'foo'
    expect do
      MultiTenant::FastTruncate.run
    end.to change { Account.count }.from(1).to(0)
  end

  it 'truncates tables that have more than one row inserted' do
    Account.create! name: 'foo'
    Account.create! name: 'bar'

    expect do
      MultiTenant::FastTruncate.run
    end.to change { Account.count }.from(2).to(0)
  end
end
