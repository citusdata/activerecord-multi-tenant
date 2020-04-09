require 'spec_helper'

describe "Query Rewriter" do

  context "when bulk updating" do
    let!(:account) { Account.create!(name: "Test Account") }
    let!(:project) { Project.create(name: "Project 1", account: account) }
    let!(:manager) { Manager.create(name: "Manager", project: project, account: account) }

    it "updates the records" do
      expect {
        MultiTenant.with(account) do
          Project.joins(:manager).update_all(name: "New Name")
        end
      }.to change { project.reload.name }.from("Project 1").to("New Name")
    end

    it "updates the records without a current tenant" do
      expect {
        Project.joins(:manager).update_all(name: "New Name")
      }.to change { project.reload.name }.from("Project 1").to("New Name")
    end

    it "update the record" do
      expect {
        MultiTenant.with(account) do
          project.update(name: "New Name")
        end
      }.to change { project.reload.name }.from("Project 1").to("New Name")
    end

    it "update the record without a current tenant" do
      expect {
        project.update(name: "New Name")
      }.to change { project.reload.name }.from("Project 1").to("New Name")
    end
  end

  context "when bulk deleting" do
    let!(:account) { Account.create!(name: "Test Account") }
    let!(:project1) { Project.create(name: "Project 1", account: account) }
    let!(:project2) { Project.create(name: "Project 2", account: account) }
    let!(:project3) { Project.create(name: "Project 3", account: account) }
    let!(:manager1) { Manager.create(name: "Manager 1", project: project1, account: account) }
    let!(:manager2) { Manager.create(name: "Manager 2", project: project2, account: account) }

    it "delete_all the records" do
      expect {
        MultiTenant.with(account) do
          Project.joins(:manager).delete_all
        end
      }.to change { Project.count }.from(3).to(1)
    end

    it "delete_all the records without a current tenant" do
      expect {
        Project.joins(:manager).delete_all
      }.to change { Project.count }.from(3).to(1)
    end

    it "delete the record" do
      expect {
        MultiTenant.with(account) do
          project1.delete
          Project.delete(project2.id)
        end
      }.to change { Project.count }.from(3).to(1)
    end

    it "delete the record without a current tenant" do
      expect {
        project1.delete
        Project.delete(project2.id)
      }.to change { Project.count }.from(3).to(1)
    end

    it "destroy the record" do
      expect {
        MultiTenant.with(account) do
          project1.destroy
          Project.destroy(project2.id)
        end
      }.to change { Project.count }.from(3).to(1)
    end

    it "destroy the record without a current tenant" do
      expect {
        project1.destroy
        Project.destroy(project2.id)
      }.to change { Project.count }.from(3).to(1)
    end
  end
end
