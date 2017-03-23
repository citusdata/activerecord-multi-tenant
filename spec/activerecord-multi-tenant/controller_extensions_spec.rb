require 'spec_helper'

describe "ActionController", type: :controller do
  before(:suite) do

    class Account
      attr_accessor :name
    end

    class ApplicationController < ActionController::Base
      include Rails.application.routes.url_helpers
      set_current_tenant_through_filter

      if ActionController::VERSION::MAJOR < 4
        before_filter :your_method_that_finds_the_current_tenant
      else
        before_action :your_method_that_finds_the_current_tenant
      end

      def your_method_that_finds_the_current_tenant
        current_account = Account.new
        current_account.name = 'account1'
        set_current_tenant(current_account)
      end
    end

    describe ApplicationController, type: :controller do
      controller do
        def index
          if ActionController::VERSION::MAJOR >= 5
            render body: 'custom called'
          else
            render text: 'custom called'
          end
        end
      end

      it 'Finds the correct tenant using the filter command' do
        get :index
        expect(MultiTenant.current_tenant.name).to eq 'account1'
      end
    end

    if ActionController::VERSION::MAJOR >= 5
      class APIApplicationController < ActionController::API
        include Rails.application.routes.url_helpers
        set_current_tenant_through_filter
        before_action :your_method_that_finds_the_current_tenant

        def your_method_that_finds_the_current_tenant
          current_account = Account.new
          current_account.name = 'account1'
          set_current_tenant(current_account)
        end
      end
    end
  end

  describe "APIApplicationController", type: :controller do
    controller do
      def index
        render body: 'custom called'
      end
    end

    it 'Finds the correct tenant using the filter command' do
      get :index
      expect(MultiTenant.current_tenant.name).to eq 'account1'
    end
  end

end
