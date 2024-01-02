# frozen_string_literal: true

require 'spec_helper'

describe 'Query Rewriter' do
  before(:each) do
    @queries = []
    ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _started, _finished, _unique_id, payload|
      @queries << payload[:sql]
    end
  end

  context 'when bulk updating' do
    let!(:account) { Account.create!(name: 'Test Account') }
    let!(:project) { Project.create(name: 'Project 1', account: account) }
    let!(:manager) { Manager.create(name: 'Manager', project: project, account: account) }

    it 'updates the records' do
      expect do
        MultiTenant.with(account) do
          Project.joins(:manager).update_all(name: 'New Name')
        end
      end.to change { project.reload.name }.from('Project 1').to('New Name')
    end

    it 'updates the records without a current tenant' do
      expect do
        Project.joins(:manager).update_all(name: 'New Name')
      end.to change { project.reload.name }.from('Project 1').to('New Name')
    end

    it 'update the record' do
      expect do
        MultiTenant.with(account) do
          project.update(name: 'New Name')
        end
      end.to change { project.reload.name }.from('Project 1').to('New Name')
    end

    it 'update the record without a current tenant' do
      expect do
        project.update(name: 'New Name')
      end.to change { project.reload.name }.from('Project 1').to('New Name')
    end

    it 'update_all the records with expected query' do
      expected_query = <<-SQL.strip
          UPDATE "projects" SET "name" = 'New Name' WHERE "projects"."id" IN
            (SELECT "projects"."id" FROM "projects"
                INNER JOIN "managers" ON "managers"."project_id" = "projects"."id"
                                    and "managers"."account_id" = :account_id
                WHERE "projects"."account_id" = :account_id
                                    )
                                    AND "projects"."account_id" = :account_id
      SQL

      expect do
        MultiTenant.with(account) do
          Project.joins(:manager).update_all(name: 'New Name')
        end
      end.to change { project.reload.name }.from('Project 1').to('New Name')

      @queries.each do |actual_query|
        next unless actual_query.include?('UPDATE "projects" SET "name"')

        expect(format_sql(actual_query)).to eq(format_sql(expected_query.gsub(':account_id', account.id.to_s)))
      end
    end

    it 'updates a limited number of records with expected query' do
      # create 2 more projects
      Project.create(name: 'project2', account: account)
      Project.create(name: 'project3', account: account)
      new_name = 'New Name'
      limit = 2
      expected_query = <<-SQL
        UPDATE
          "projects"
        SET
          "name" = 'New Name'
        WHERE
          "projects"."id" IN (
            SELECT
              "projects"."id"
            FROM
              "projects"
            WHERE
              "projects"."account_id" = #{account.id} LIMIT #{limit}
          )
          AND "projects"."account_id" = #{account.id}
      SQL

      expect do
        MultiTenant.with(account) do
          Project.limit(limit).update_all(name: new_name)
        end
      end.to change { Project.where(name: new_name).count }.from(0).to(limit)

      @queries.each do |actual_query|
        next unless actual_query.include?('UPDATE "projects" SET "name"')

        expect(format_sql(actual_query.gsub('$1',
                                            limit.to_s)).strip).to eq(format_sql(expected_query).strip)
      end
    end
  end

  context 'when bulk deleting' do
    let!(:account) { Account.create!(name: 'Test Account') }
    let!(:project1) { Project.create(name: 'Project 1', account: account) }
    let!(:project2) { Project.create(name: 'Project 2', account: account) }
    let!(:project3) { Project.create(name: 'Project 3', account: account) }
    let!(:manager1) { Manager.create(name: 'Manager 1', project: project1, account: account) }
    let!(:manager2) { Manager.create(name: 'Manager 2', project: project2, account: account) }

    before(:each) do
      @queries = []
      ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _started, _finished, _unique_id, payload|
        @queries << payload[:sql]
      end
    end

    after(:each) do
      ActiveSupport::Notifications.unsubscribe('sql.active_record')
    end

    it 'delete_all the records' do
      expected_query = <<-SQL.strip
          DELETE FROM "projects" WHERE "projects"."id" IN
            (SELECT "projects"."id" FROM "projects"
                INNER JOIN "managers" ON "managers"."project_id" = "projects"."id"
                                    and "managers"."account_id" = :account_id
                WHERE "projects"."account_id" = :account_id
                                    )
                                    AND "projects"."account_id" = :account_id
      SQL

      expect do
        MultiTenant.with(account) do
          Project.joins(:manager).delete_all
        end
      end.to change { Project.count }.from(3).to(1)

      @queries.each do |actual_query|
        next unless actual_query.include?('DELETE FROM ')

        expect(format_sql(actual_query)).to eq(format_sql(expected_query.gsub(':account_id', account.id.to_s)))
      end
    end

    it 'delete_all the records without a current tenant' do
      expect do
        Project.joins(:manager).delete_all
      end.to change { Project.count }.from(3).to(1)
    end

    it 'delete the record' do
      expect do
        MultiTenant.with(account) do
          project1.delete
          Project.delete(project2.id)
        end
      end.to change { Project.count }.from(3).to(1)
    end

    it 'delete the record without a current tenant' do
      expect do
        project1.delete
        Project.delete(project2.id)
      end.to change { Project.count }.from(3).to(1)
    end

    it 'deletes a limited number of records with expected query' do
      # create 2 more projects
      Project.create(name: 'project2', account: account)
      Project.create(name: 'project3', account: account)
      limit = 2
      expected_query = <<-SQL
        DELETE FROM
          "projects"
        WHERE
          "projects"."id" IN (
            SELECT
              "projects"."id"
            FROM
              "projects"
            WHERE
              "projects"."account_id" = #{account.id} LIMIT #{limit}
          )
          AND "projects"."account_id" = #{account.id}
      SQL

      expect do
        MultiTenant.with(account) do
          Project.limit(limit).delete_all
        end
      end.to change { Project.count }.by(-limit)

      @queries.each do |actual_query|
        next unless actual_query.include?('DELETE FROM "projects"')

        expect(format_sql(actual_query.gsub('$1',
                                            limit.to_s)).strip).to eq(format_sql(expected_query).strip)
      end
    end

    it 'destroy the record' do
      expect do
        MultiTenant.with(account) do
          project1.destroy
          Project.destroy(project2.id)
        end
      end.to change { Project.count }.from(3).to(1)
    end

    it 'destroy the record without a current tenant' do
      expect do
        project1.destroy
        Project.destroy(project2.id)
      end.to change { Project.count }.from(3).to(1)
    end
  end

  context 'when update without arel' do
    it 'can call method' do
      expect do
        ActiveRecord::Base.connection.update('SELECT 1')
      end.not_to raise_error
    end
  end

  context 'when joining with a model with a default scope' do
    let!(:account) { Account.create!(name: 'Test Account') }

    it 'fetches only records within the default scope' do
      alive = Domain.create(name: 'alive', account: account)
      deleted = Domain.create(name: 'deleted', deleted: true, account: account)
      page_in_alive_domain = Page.create(name: 'alive', account: account, domain: alive)
      Page.create(name: 'deleted', account: account, domain: deleted)

      expect(
        MultiTenant.with(account) do
          Page.joins(:domain).pluck(:id)
        end
      ).to eq([page_in_alive_domain.id])
    end
  end
end
