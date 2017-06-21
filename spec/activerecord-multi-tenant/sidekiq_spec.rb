require 'spec_helper'
require 'sidekiq/client'
require 'activerecord-multi-tenant/sidekiq'

describe MultiTenant, 'Sidekiq' do
  let(:server) { Sidekiq::Middleware::MultiTenant::Server.new }

  describe 'server middleware' do
    it 'sets the multitenant context when provided in message' do
      tenant_id = 1234
      server.call(double, {'bogus' => 'message',
        'multi_tenant' => { 'class' => MultiTenant.current_tenant_class, 'id' => tenant_id}},
        'bogus_queue') do
        expect(MultiTenant.current_tenant).to eq(tenant_id)
      end
    end

    it 'does not set the multitenant context when no tenant provided' do
      server.call(double, {'bogus' => 'message'}, 'bogus_queue') do
        expect(MultiTenant.current_tenant).to be_nil
      end
    end
  end
end
