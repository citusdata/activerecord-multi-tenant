require 'spec_helper'

RSpec.describe MultiTenant do
  describe ".load_current_tenant!" do
    let(:fake_tenant) { OpenStruct.new(id: 1) }
    let(:mock_klass) { double(find: fake_tenant) }

    before do
      @original_default_class = MultiTenant.default_tenant_class
      MultiTenant.default_tenant_class = mock_klass
    end

    after do
      MultiTenant.default_tenant_class = @original_default_class
    end

    it "sets and returns the loaded current_tenant" do
      expect(mock_klass).to receive(:find).once.with(1)
      MultiTenant.current_tenant = 1
      expect(MultiTenant.load_current_tenant!).to eq(fake_tenant)
      expect(MultiTenant.current_tenant).to eq(fake_tenant)
    end

    it "respects `.with` lifecycle" do
      expect(mock_klass).to receive(:find).once.with(2)
      expect(MultiTenant.current_tenant).to eq(nil)
      MultiTenant.with(2) do
        expect(MultiTenant.load_current_tenant!).to eq(fake_tenant)
        expect(MultiTenant.current_tenant).to eq(fake_tenant)
      end
      expect(MultiTenant.current_tenant).to eq(nil)
    end

    context "with a loaded current_tenant" do
      it "returns the tenant without fetching it" do
        expect(mock_klass).not_to receive(:find)
        MultiTenant.current_tenant = fake_tenant
        expect(MultiTenant.load_current_tenant!).to eq(fake_tenant)
      end
    end

    context "with a nil current_tenant" do
      it "raises an error, as there is not enough information to load the tenant" do
        expect(mock_klass).not_to receive(:find)
        expect {
          MultiTenant.load_current_tenant!
        }.to raise_error(RuntimeError, 'MultiTenant.current_tenant must be set to load')
      end
    end

    context "without a default class set" do
      before do
        MultiTenant.default_tenant_class = nil
      end

      it "raises an error, as there is not enough information to load the tenant" do
        expect(mock_klass).not_to receive(:find)
        MultiTenant.current_tenant = 1
        expect {
          MultiTenant.load_current_tenant!
        }.to raise_error(RuntimeError, 'Only have tenant id, and no default tenant class set')
      end
    end
  end
end
