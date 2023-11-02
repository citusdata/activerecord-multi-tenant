# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MultiTenant do
  describe '.load_current_tenant!' do
    let(:fake_tenant) { double(id: 1) }
    let(:mock_klass) { double(find: fake_tenant) }

    before do
      @original_default_class = MultiTenant.default_tenant_class
      MultiTenant.default_tenant_class = mock_klass
    end

    after do
      MultiTenant.default_tenant_class = @original_default_class
    end

    it 'sets and returns the loaded current_tenant' do
      expect(mock_klass).to receive(:find).once.with(1)
      MultiTenant.current_tenant = 1
      expect(MultiTenant.load_current_tenant!).to eq(fake_tenant)
      expect(MultiTenant.current_tenant).to eq(fake_tenant)
    end

    it 'respects `.with` lifecycle' do
      expect(mock_klass).to receive(:find).once.with(2)
      expect(MultiTenant.current_tenant).to eq(nil)
      MultiTenant.with(2) do
        expect(MultiTenant.load_current_tenant!).to eq(fake_tenant)
        expect(MultiTenant.current_tenant).to eq(fake_tenant)
      end
      expect(MultiTenant.current_tenant).to eq(nil)
    end

    context 'with a loaded current_tenant' do
      it 'returns the tenant without fetching it' do
        expect(mock_klass).not_to receive(:find)
        MultiTenant.current_tenant = fake_tenant
        expect(MultiTenant.load_current_tenant!).to eq(fake_tenant)
      end
    end

    context 'with a nil current_tenant' do
      it 'raises an error, as there is not enough information to load the tenant' do
        expect(mock_klass).not_to receive(:find)
        expect do
          MultiTenant.load_current_tenant!
        end.to raise_error(RuntimeError, 'MultiTenant.current_tenant must be set to load')
      end
    end

    context 'without a default class set' do
      before do
        MultiTenant.default_tenant_class = nil
      end

      it 'raises an error, as there is not enough information to load the tenant' do
        expect(mock_klass).not_to receive(:find)
        MultiTenant.current_tenant = 1
        expect do
          MultiTenant.load_current_tenant!
        end.to raise_error(RuntimeError, 'Only have tenant id, and no default tenant class set')
      end
    end
  end

  describe '.tenant_klass_defined?' do
    context 'without options' do
      before(:all) do
        class SampleTenant < ActiveRecord::Base
          multi_tenant :sample_tenant
        end
      end

      it 'return true with valid tenant_name' do
        expect(MultiTenant.tenant_klass_defined?(:sample_tenant)).to eq(true)
      end

      it 'return false with invalid_tenant_name' do
        invalid_tenant_name = :tenant
        expect(MultiTenant.tenant_klass_defined?(invalid_tenant_name)).to eq(false)
      end
    end

    context 'with options' do
      context 'and valid class_name' do
        it 'return true' do
          class SampleTenant < ActiveRecord::Base
            multi_tenant :tenant
          end

          tenant_name = :tenant
          options = {
            class_name: 'SampleTenant'
          }
          expect(MultiTenant.tenant_klass_defined?(tenant_name, options)).to eq(true)
        end

        it 'return true when tenant class is nested' do
          module SampleModule
            class SampleNestedTenant < ActiveRecord::Base
              multi_tenant :tenant
            end
            # rubocop:disable Layout/TrailingWhitespace
            # Trailing whitespace is intentionally left here
            
            class AnotherTenant < ActiveRecord::Base
            end
            # rubocop:enable Layout/TrailingWhitespace
          end
          tenant_name = :tenant
          options = {
            class_name: 'SampleModule::SampleNestedTenant'
          }
          expect(MultiTenant.tenant_klass_defined?(tenant_name, options)).to eq(true)
        end
      end
    end
  end

  describe '.wrap_methods' do
    context 'when method is already prepended' do
      it 'is not an stack error' do
        klass = Class.new do
          def hello
            'hello'
          end
        end

        klass.prepend(Module.new do
          def hello
            "#{super} world"
          end

          def owner
            Class.new(ActiveRecord::Base) do
              self.table_name = 'accounts'
            end.new
          end
        end)

        MultiTenant.wrap_methods(klass, :owner, :hello)

        expect(klass.new.hello).to eq('hello world')
      end
    end
  end
end
