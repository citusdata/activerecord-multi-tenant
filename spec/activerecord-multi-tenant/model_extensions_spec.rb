require 'spec_helper'

describe MultiTenant do
  after { MultiTenant.current_tenant = nil }

  # Setting and getting
  describe 'Setting the current tenant' do
    before { MultiTenant.current_tenant = :foo }
    it { MultiTenant.current_tenant == :foo }
  end

  describe 'is_scoped_as_tenant should return the correct value when true' do
    it {expect(Project.respond_to?(:scoped_by_tenant?)).to eq(true)}
  end

  describe 'is_scoped_as_tenant should return the correct value when false' do
    it {expect(UnscopedModel.respond_to?(:scoped_by_tenant?)).to eq(false)}
  end

  context 'immutability' do
    before do
      @account = Account.create! name: 'foo'
      MultiTenant.with(@account) do
        @project = @account.projects.create! name: 'bar'
      end
    end

    describe 'tenant_id should be immutable, if already set' do
      it { expect { @project.account_id = @account.id + 1 }.to raise_error(MultiTenant::TenantIsImmutable) }
    end

    describe 'setting tenant_id to the same value should not error' do
      it { expect { @project.account_id = @account.id }.not_to raise_error }
    end

    describe 'setting tenant_id to a string with same to_i value should not error' do
      it { expect { @project.account_id = @account.id.to_s }.not_to raise_error }
    end
  end

  describe 'tenant_id should auto populate after initialization' do
    before do
      @account = Account.create! name: 'foo'
      MultiTenant.current_tenant = @account
    end
    it {expect(Project.new.account_id).to eq(@account.id)}
    it 'should handle partial selects' do
      project = Project.create!
      expect{project = Project.select(:name).find(project.id)}.not_to raise_error
      expect(project.account_id).to eq(@account.id)
    end
  end

  describe 'Handles custom partition_key on tenant model' do
    before do
      @account  = Account.create! name: 'foo'
      MultiTenant.current_tenant = @account
      @custom_partition_key_task = CustomPartitionKeyTask.create! name: 'foo'
    end

    it { expect(@custom_partition_key_task.account).to eq(@account) }
  end

  describe 'Tenant model not defined' do
    before do
      MultiTenant.current_tenant = 77
      @partition_key_not_model_task = PartitionKeyNotModelTask.create! name: 'foo'
    end

    it { expect(@partition_key_not_model_task.non_model_id).to be 77 }
  end

  # Scoping models
  describe 'Project.all should be scoped to the current tenant if set' do
    before do
      @account1 = Account.create! name: 'foo'
      @account2 = Account.create! name: 'bar'

      @project1 = @account1.projects.create! name: 'foobar'
      @project2 = @account2.projects.create! name: 'baz'

      MultiTenant.current_tenant = @account1
      @projects = Project.all
    end

    it { expect(@projects.length).to eq(1) }
    it { expect(@projects).to eq([@project1]) }
  end

  describe 'Querying the tenant from a scoped model with a tenant set' do
    before do
      @account = Account.create! name: 'foo'
      @project = @account.projects.create! name: 'foobar'
      MultiTenant.current_tenant = @account1
    end

    it { @project.account }
  end

  # Associations
  describe 'Associations should be correctly scoped by current tenant' do
    before do
      @account = Account.create! name: 'foo'
      @project = Project.create! name: 'foobar', account: @account

      MultiTenant.current_tenant = @account
      @task = @project.tasks.create! name: 'baz'
    end

    it 'should correctly set the tenant on the task created with current_tenant set' do
      expect(@task.account).to eq(@account)
    end
  end

  describe "It should be possible to use aliased associations" do
    before do
      @account = Account.create! name: 'baz'
      MultiTenant.current_tenant = @account
    end

    it { expect(AliasedTask.create(:name => 'foo', :project_alias => @project2).valid?).to eq(true) }
  end

  describe "It should be possible to use associations with partition_key from polymorphic" do
    before do
      @account = Account.create!(name: 'foo')
      MultiTenant.current_tenant = @account
      @project = Project.create!(name: 'project', account: @account)
      @comment = Comment.new commentable: @project, account: @account
    end

    it { expect(@comment.save!).to eq(true) }
  end

  describe 'association through' do
    let(:account) { Account.create!(name: 'foo') }
    let(:project) { Project.create!(name: 'project', account: account) }
    let(:task) { project.tasks.create!(name: 'task') }
    let(:sub_task) { task.sub_tasks.create!(name: 'sub task') }

    it 'handles belongs_to through' do
      MultiTenant.with(account) do
        expect(sub_task.project).to eq project
      end
    end

    it 'handles has_many through' do
      MultiTenant.with(account) do
        expect(project.sub_tasks).to eq [sub_task]
      end
    end
  end

  describe 'eager loading' do
    let(:account) { Account.create!(name: 'foo') }
    let(:project) { Project.create!(name: 'project', account: account) }
    let(:manager) { Manager.create!(name: 'manager', account: account, project: project) }
    let(:task) { project.tasks.create!(name: 'eager loading test task') }
    let(:sub_task) { task.sub_tasks.create!(name: 'eager loading test sub task') }

    it 'handles table aliases through joins' do
      MultiTenant.with(account) do
        sub_task
        manager
        expect(Project.eager_load([{manager: :project}, {tasks: :project}]).first).to eq project
      end
    end
  end

  describe 'sub selects' do
    let(:account) { Account.create!(name: 'foo') }
    let(:project) { Project.create!(name: 'project', account: account) }

    it 'rewrites sub-selects correctly' do
      MultiTenant.with(account) do
        expect(Project.where(id: Project.where(id: project.id)).where(id: Project.where(id: project.id)).first).to eq project
      end
    end
  end

  describe 'STI Subclass of Multi Tenant Model' do
    let(:account) { Account.create!(name: 'foo') }
    let(:project) { Project.create!(name: 'project', account: account) }
    let(:task) { project.tasks.create!(name: 'subclass test task') }
    let(:sti_task) { StiSubTask.create!(task: task, name: 'subclass test sub task') }

    it 'has partition key' do
      expect(StiSubTask.partition_key).to eq 'account_id'
      expect(StiSubTask.instance_variable_get(:@partition_key)).to eq 'account_id'
    end

    it 'has primary key' do
      expect(StiSubTask.primary_key).to eq 'id'
    end

    it 'handles associations' do
      MultiTenant.with(account) do
        expect(sti_task.project).to eq project
        expect(project.sub_tasks.to_a).to eq [sti_task]
      end
    end
  end

  describe 'non-STI Subclass of abstract Multi Tenant Model' do
    let(:tenant_id_1) { 42 }
    let(:tenant_id_2) { 314158 }
    let(:name) { 'fooname' }
    let(:subclass_task_1) do
      MultiTenant.with(tenant_id_1) { SubclassTask.create! name: name }
    end
    let(:subclass_task_2) do
      MultiTenant.with(tenant_id_2) { SubclassTask.create! name: name }
    end

    before do
      subclass_task_1
      subclass_task_2
    end

    it 'injects tenant_id on create' do
      expect(subclass_task_1.non_model_id).to be tenant_id_1
      expect(subclass_task_2.non_model_id).to be tenant_id_2
    end

    it 'rewrites query' do
      MultiTenant.with(tenant_id_1) do
        expect(SubclassTask.where(name: name).count).to eq 1
        expect(SubclassTask.where(name: name).first).to eq subclass_task_1
      end
      MultiTenant.with(tenant_id_2) do
        expect(SubclassTask.where(name: name).count).to eq 1
        expect(SubclassTask.where(name: name).first).to eq subclass_task_2
      end
    end
  end

  # ::with
  describe "::with" do
    it "should set current_tenant to the specified tenant inside the block" do
      @account = Account.create!(:name => 'baz')

      MultiTenant.with(@account) do
        expect(MultiTenant.current_tenant).to eq(@account)
      end
    end

    it "should reset current_tenant to the previous tenant once exiting the block" do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      MultiTenant.current_tenant = @account1
      MultiTenant.with @account2 do

      end

      expect(MultiTenant.current_tenant).to eq(@account1)
    end

    it "should return the value of the block" do
      @account1 = Account.create!(:name => 'foo')
      @account2 = Account.create!(:name => 'bar')

      MultiTenant.current_tenant = @account1
      value = MultiTenant.with @account2 do
        "something"
      end

      expect(value).to eq "something"
    end

    it 'supports reload inside the block' do
      @account = Account.create!(name: 'foo')

      MultiTenant.with @account do
        project = @account.projects.create!(name: 'project')
        project.reload
        expect(project.name).to eq 'project'
      end
    end
  end

  # ::without
  describe "::without" do
    it "should unset current_tenant inside the block" do
      @account = Account.create!(:name => 'baz')

      MultiTenant.current_tenant = @account
      MultiTenant.without do
        expect(MultiTenant.current_tenant).to eq(nil)
      end
    end

    it "should reset current_tenant to the previous tenant once exiting the block" do
      @account1 = Account.create!(:name => 'foo')

      MultiTenant.current_tenant = @account1
      MultiTenant.without do

      end

      expect(MultiTenant.current_tenant).to eq(@account1)
    end

    it "should return the value of the block" do
      @account1 = Account.create!(:name => 'foo')

      MultiTenant.current_tenant = @account1
      value = MultiTenant.without do
        "something"
      end

      expect(value).to eq "something"
    end
  end

  describe '.with_lock' do
    it 'supports with_lock blocks inside the block' do
      @account = Account.create!(name: 'foo')

      MultiTenant.with @account do
        project = @account.projects.create!(name: 'project')
        project.with_lock do
          expect(project.name).to eq 'project'
        end
      end
    end
  end

  it 'does not cache tenancy in associations' do
    account1 = Account.create! name: 'test1'
    account2 = Account.create! name: 'test2'

    MultiTenant.with(account1) do
      project1 = Project.create! name: 'something1'
      task1 = Task.create! name: 'task1', project: project1
      subtask1 = SubTask.create! task: task1

      expect(subtask1.project).to be_present
    end

    MultiTenant.with(account2) do
      project2 = Project.create! name: 'something2'
      task2 = Task.create! name: 'task2', project: project2
      subtask2 = SubTask.create! task: task2

      expect(subtask2.project).to be_present
    end
  end

  it "applies the team_id conditions in the where clause" do
    option1 = <<-sql.strip
      SELECT "sub_tasks".* FROM "sub_tasks" INNER JOIN "tasks" ON "sub_tasks"."task_id" = "tasks"."id" AND "sub_tasks"."account_id" = "tasks"."account_id" WHERE "tasks"."project_id" = 1 AND "sub_tasks"."account_id" = 1 AND "tasks"."account_id" = 1
    sql
    option2 = <<-sql.strip
      SELECT "sub_tasks".* FROM "sub_tasks" INNER JOIN "tasks" ON "sub_tasks"."task_id" = "tasks"."id" AND "sub_tasks"."account_id" = "tasks"."account_id" WHERE "sub_tasks"."account_id" = 1 AND "tasks"."project_id" = 1 AND "tasks"."account_id" = 1
    sql

    account1 = Account.create! name: 'Account 1'

    MultiTenant.with(account1) do
      project1 = Project.create! name: 'Project 1'
      task1 = Task.create! name: 'Task 1', project: project1
      subtask1 = SubTask.create! task: task1
      expect(project1.sub_tasks.to_sql).to eq(option1).or(eq(option2))
      expect(project1.sub_tasks).to include(subtask1)
    end

    MultiTenant.without do
      expected_sql = <<-sql
                        SELECT "sub_tasks".* FROM "sub_tasks" INNER JOIN "tasks" ON "sub_tasks"."task_id" = "tasks"."id" AND "sub_tasks"."account_id" = "tasks"."account_id" WHERE "tasks"."project_id" = 1
                     sql

      project = Project.first
      expect(project.sub_tasks.to_sql).to eq(expected_sql.strip)
    end
  end

  it "tests joins between distributed and reference table" do
    option1 = <<-sql.strip
      SELECT "categories".* FROM "categories" INNER JOIN "project_categories" ON "categories"."id" = "project_categories"."category_id" WHERE "project_categories"."project_id" = 1 AND "project_categories"."account_id" = 1
    sql
    option2 = <<-sql.strip
      SELECT "categories".* FROM "categories" INNER JOIN "project_categories" ON "categories"."id" = "project_categories"."category_id" WHERE "project_categories"."account_id" = 1 AND "project_categories"."project_id" = 1
    sql

    account1 = Account.create! name: 'Account 1'
    category1 = Category.create! name: 'Category 1'

    MultiTenant.with(account1) do
      project1 = Project.create! name: 'Project 1'
      projectcategory = ProjectCategory.create! name: 'project cat 1', project: project1, category: category1

      expect(project1.categories.to_sql).to eq(option1).or(eq(option2))
      expect(project1.categories).to include(category1)
      expect(project1.project_categories).to include(projectcategory)
    end

    MultiTenant.without do
      expected_sql = <<-sql
                     SELECT "categories".* FROM "categories" INNER JOIN "project_categories" ON "categories"."id" = "project_categories"."category_id" WHERE "project_categories"."project_id" = 1
                     sql

      project = Project.first
      expect(project.categories.to_sql).to eq(expected_sql.strip)
      expect(project.categories).to include(category1)

      expected_sql = <<-sql
                        SELECT "projects".* FROM "projects" INNER JOIN "project_categories" ON "project_categories"."project_id" = "projects"."id" AND "project_categories"."account_id" = "projects"."account_id" INNER JOIN "categories" ON "categories"."id" = "project_categories"."category_id" WHERE "projects"."account_id" = 1
                    sql

      expect(Project.where(account_id: 1).joins(:categories).to_sql).to eq(expected_sql.strip)
      project = Project.where(account_id: 1).joins(:categories).first
      expect(project.categories).to include(category1)
    end
  end


  it "test eager_load" do
    account1 = Account.create! name: 'Account 1'
    category1 = Category.create! name: 'Category 1'

    option1 = <<-sql.strip
      SELECT "projects"."id" AS t0_r0, "projects"."account_id" AS t0_r1, "projects"."name" AS t0_r2, "categories"."id" AS t1_r0, "categories"."name" AS t1_r1 FROM "projects" LEFT OUTER JOIN "project_categories" ON "project_categories"."project_id" = "projects"."id" AND "project_categories"."account_id" = 1 AND "projects"."account_id" = 1 LEFT OUTER JOIN "categories" ON "categories"."id" = "project_categories"."category_id" AND "project_categories"."account_id" = 1 WHERE "projects"."account_id" = 1
    sql
    option2 = <<-sql.strip
      SELECT "projects"."id" AS t0_r0, "projects"."account_id" AS t0_r1, "projects"."name" AS t0_r2, "categories"."id" AS t1_r0, "categories"."name" AS t1_r1 FROM "projects" LEFT OUTER JOIN "project_categories" ON "project_categories"."account_id" = 1 AND "project_categories"."project_id" = "projects"."id" AND "projects"."account_id" = 1 LEFT OUTER JOIN "categories" ON "categories"."id" = "project_categories"."category_id" AND "project_categories"."account_id" = 1 WHERE "projects"."account_id" = 1
    sql

    MultiTenant.with(account1) do
      project1 = Project.create! name: 'Project 1'
      projectcategory = ProjectCategory.create! name: 'project cat 1', project: project1, category: category1

      expect(Project.eager_load(:categories).to_sql).to eq(option1).or(eq(option2))

      project = Project.eager_load(:categories).first
      expect(project.categories).to include(category1)
      expect(project.project_categories).to include(projectcategory)
    end

    MultiTenant.without do
      expected_sql = <<-sql
                     SELECT "projects"."id" AS t0_r0, "projects"."account_id" AS t0_r1, "projects"."name" AS t0_r2, "categories"."id" AS t1_r0, "categories"."name" AS t1_r1 FROM "projects" LEFT OUTER JOIN "project_categories" ON "project_categories"."project_id" = "projects"."id" AND "project_categories"."account_id" = "projects"."account_id" LEFT OUTER JOIN "categories" ON "categories"."id" = "project_categories"."category_id" WHERE "projects"."account_id" = 1
                     sql

      expect(Project.where(account_id: 1).eager_load(:categories).to_sql).to eq(expected_sql.strip)

      project = Project.where(account_id: 1).eager_load(:categories).first
      expect(project.categories).to include(category1)

    end
  end

  it "test raw SQL joins" do
    account1 = Account.create! name: 'Account 1'
    category1 = Category.create! name: 'Category 1'

    MultiTenant.with(account1) do

      option1 = <<-sql.strip
        SELECT "tasks".* FROM "tasks" INNER JOIN "projects" ON "projects"."id" = "tasks"."project_id" AND "projects"."account_id" = 1 LEFT JOIN project_categories pc ON project.category_id = pc.id WHERE "tasks"."account_id" = 1
      sql
      option2 = <<-sql.strip
        SELECT "tasks".* FROM "tasks" INNER JOIN "projects" ON "projects"."account_id" = 1 AND "projects"."id" = "tasks"."project_id" LEFT JOIN project_categories pc ON project.category_id = pc.id WHERE "tasks"."account_id" = 1
      sql

      project1 = Project.create! name: 'Project 1'
      projectcategory = ProjectCategory.create! name: 'project cat 1', project: project1, category: category1

      project1.tasks.create! name: 'baz'
      expect(Task.joins(:project).joins('LEFT JOIN project_categories pc ON project.category_id = pc.id').to_sql).to eq(option1).or(eq(option2))
    end

    MultiTenant.without do
      expected_sql = <<-sql
                     SELECT "tasks".* FROM "tasks" INNER JOIN "projects" ON "projects"."id" = "tasks"."project_id" AND "projects"."account_id" = "tasks"."account_id" LEFT JOIN project_categories pc ON project.category_id = pc.id WHERE "tasks"."account_id" = 1
                     sql

      expect(Task.where(account_id: 1).joins(:project).joins('LEFT JOIN project_categories pc ON project.category_id = pc.id').to_sql).to eq(expected_sql.strip)

    end

  end

  it "only applies clauses when a tenant is set" do
    account = Account.create! name: 'Account 1'
    project = Project.create! name: 'Project 1', account: account
    project2 = Project.create! name: 'Project 2', account: Account.create!(name: 'Account2')

    MultiTenant.with(account) do
      option1 = <<-sql.strip
        SELECT "projects".* FROM "projects" WHERE "projects"."account_id" = #{account.id} AND "projects"."id" = $1 LIMIT $2
      sql
      option2 = <<-sql.strip
        SELECT "projects".* FROM "projects" WHERE "projects"."id" = $1 AND "projects"."account_id" = #{account.id} LIMIT $2
      sql
      option3 = <<-sql.strip
        SELECT  "projects".* FROM "projects" WHERE "projects"."id" = $1 AND "projects"."account_id" = #{account.id} LIMIT $2
      sql

      expect(Project).to receive(:find_by_sql).with(eq(option1).or(eq(option2)).or(eq(option3)), any_args).and_call_original
      expect(Project.find(project.id)).to eq(project)
    end

    MultiTenant.without do
      option1 = <<-sql.strip
        SELECT "projects".* FROM "projects" WHERE "projects"."id" = $1 LIMIT $2
      sql
      option2 = <<-sql.strip
        SELECT  "projects".* FROM "projects" WHERE "projects"."id" = $1 LIMIT $2
      sql

      expect(Project).to receive(:find_by_sql).with(eq(option1).or(eq(option2)), any_args).and_call_original
      expect(Project.find(project2.id)).to eq(project2)
    end
  end


  describe 'with unsaved association' do
    before do
      @account = Account.create!(name: 'reflection tenant')
      @manager = Manager.new(account: @account)
      MultiTenant.current_tenant = @account
      @account.update! name: 'reflection tenant update'
    end

    it 'persists the reflected association' do
      expect(@manager.persisted?).to eq(true)
    end
  end

  it "test value of RETURNING insert in table with no pkey" do
    account1 = Account.create(name: 'test1')

    MultiTenant.with(account1) do
      allowed_place = AllowedPlace.create! name: 'something1'

      project = Project.create! name: 'Project 1'
    end
  end
end
