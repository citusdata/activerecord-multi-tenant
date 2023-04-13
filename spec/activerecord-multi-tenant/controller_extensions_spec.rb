# frozen_string_literal: true

require 'spec_helper'

describe 'Controller Extensions', type: :controller do
  class Account
    attr_accessor :name
  end

  class ApplicationController < ActionController::Base
    include Rails.application.routes.url_helpers
    set_current_tenant_through_filter

    before_action :your_method_that_finds_the_current_tenant

    def your_method_that_finds_the_current_tenant
      current_account = Account.new
      current_account.name = 'account1'
      set_current_tenant(current_account)
    end
  end

  describe ApplicationController, type: :controller do
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

  describe APIApplicationController, type: :controller do
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
