# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Arel::Visitors::ToSql do
  let(:connection) { ActiveRecord::Base.connection }
  let(:visitor) { described_class.new connection }
  let(:compiled) { visitor.accept(node, Arel::Collectors::SQLString.new).value }

  describe 'with sql' do
    let(:node) { Arel::Subquery.new('SELECT * FROM "clients"', as: 'users') }

    it 'visits_Arel_Subquery' do
      expect(compiled).to eq '(SELECT * FROM "clients") "users"'
    end
  end

  describe 'with project' do
    let(:node) do
      clients = Arel::Table.new(:clients)
      Arel::Subquery.new(clients.project(Arel.star), as: 'users')
    end

    it 'visits_Arel_Subquery' do
      expect(compiled).to eq '(SELECT * FROM "clients") "users"'
    end
  end
end
