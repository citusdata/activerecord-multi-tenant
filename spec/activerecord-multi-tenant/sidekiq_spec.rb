# frozen_string_literal: true

require 'spec_helper'
require 'sidekiq/client'
require 'activerecord-multi-tenant/sidekiq'

describe MultiTenant, 'Sidekiq' do
  let(:server) { Sidekiq::Middleware::MultiTenant::Server.new }
  let(:account) { Account.create(name: 'test') }
  let(:deleted_account) { Account.create(name: 'deleted') }

  before { deleted_account.destroy! }

  describe 'server middleware' do
    it 'sets the multitenant context when provided in message' do
      server.call(double, { 'bogus' => 'message',
                            'multi_tenant' => { 'class' => account.class.name, 'id' => account.id } },
                  'bogus_queue') do
        expect(MultiTenant.current_tenant).to eq(account)
      end
    end

    it 'sets the multitenant context (id) even if tenant not found' do
      server.call(double, { 'bogus' => 'message',
                            'multi_tenant' => { 'class' => deleted_account.class.name, 'id' => deleted_account.id } },
                  'bogus_queue') do
        expect(MultiTenant.current_tenant).to eq(deleted_account.id)
      end
    end

    it 'does not set the multitenant context when no tenant provided' do
      server.call(double, { 'bogus' => 'message' }, 'bogus_queue') do
        expect(MultiTenant.current_tenant).to be_nil
      end
    end
  end
end
