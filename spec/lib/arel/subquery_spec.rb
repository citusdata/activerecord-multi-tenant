# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arel::Subquery do
  describe 'new' do
    let(:table) { described_class.new 'SELECT * FROM clients', as: 'users' }

    it 'sets the data_source' do
      expect(table.data_source).to eq 'SELECT * FROM clients'
    end

    it 'sets the name with the as attribute' do
      expect(table.name).to eq 'users'
    end

    it 'does not set any alias' do
      expect(table.table_alias).to be_nil
    end
  end
end
