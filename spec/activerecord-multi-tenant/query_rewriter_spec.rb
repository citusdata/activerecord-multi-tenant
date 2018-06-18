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

    it "update the record" do
      expect {
        MultiTenant.with(account) do
          project.update(name: "New Name")
        end
      }.to change { project.reload.name }.from("Project 1").to("New Name")
    end
  end

  context "when bulk deleting" do
    let!(:account) { Account.create!(name: "Test Account") }
    let!(:project) { Project.create(name: "Project 1", account: account) }
    let!(:manager) { Manager.create(name: "Manager", project: project, account: account) }

    it "deletes the records" do
      expect {
        MultiTenant.with(account) do
          Project.joins(:manager).delete_all
        end
      }.to change { Project.count }.from(1).to(0)
    end

    it "destroy the record" do
      expect {
        MultiTenant.with(account) do
          project.destroy
        end
      }.to change { Project.count }.from(1).to(0)
    end
  end
end
