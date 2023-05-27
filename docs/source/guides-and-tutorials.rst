.. _guides-and-tutorials:

Guides and Tutorials
====================

This section provides step-by-step guides and tutorials on how to use ``activerecord-multi-tenant`` in various scenarios.

Setting Up Multi tenancy in a New Project
------------------------------------------

To set up multi-tenancy in a new Rails project, follow these steps:

1. Install the ``activerecord-multi-tenant`` gem as described in the :ref:`getting-started` section.

2. Declare your tenant model in your ActiveRecord models:

   .. code-block:: ruby

      class User < ActiveRecord::Base
        multi_tenant :company
      end

3. Set the current tenant before executing queries:

   .. code-block:: ruby

      ActiveRecord::MultiTenant.current_tenant = Company.first
      @users = User.all

Migrating an Existing Project to Use ``activerecord-multi-tenant``
------------------------------------------------------------------

If you have an existing Rails project and you want to add multi-tenancy support, follow these steps:

1. Install the ``activerecord-multi-tenant`` gem as described in the :ref:`getting-started` section.

2. Update your ActiveRecord models to declare the tenant model:

   .. code-block:: ruby

      class User < ActiveRecord::Base
        multi_tenant :company
      end

3. Update your application logic to set the current tenant before executing queries.


Using ``has_many`` , ``has_one`` , and ``belongs_to`` Associations
------------------------------------------------------------------

When using ``has_many``, ``has_one``, and ``belongs_to`` associations,
there is nothing special you need to do to make them work with ``activerecord-multi-tenant``.
The gem will automatically scope the associations to the current tenant.:

.. code-block:: ruby

   class User < ActiveRecord::Base
     multi_tenant :company
     has_many :posts
   end

   class Post < ActiveRecord::Base
     belongs_to :user
   end

   ActiveRecord::MultiTenant.with(Company.first) do
     @user = User.first
     @user.posts # => Returns posts belonging to Company.first
   end

Using ``has_and_belongs_to_many`` Associations
-----------------------------------------------

When using ``has_and_belongs_to_many`` associations, you need to specify the tenant column and tenant class name to
scope the association to the current tenant. If you set the ``tenant_enabled`` option to ``false``, the gem will
not scope the association to the current tenant.

.. code-block:: ruby

    class Account < ActiveRecord::Base
      multi_tenant :account
      has_many :projects
      has_one :manager, inverse_of: :account
      has_many :optional_sub_tasks
    end

    class Manager < ActiveRecord::Base
      multi_tenant :account
      belongs_to :project
      has_and_belongs_to_many :tasks, { tenant_column: :account_id, tenant_enabled: true,
                                        tenant_class_name: 'Account' }
    end

    # Tests to check if the tenant column is set correctly
    let(:task1) { Task.create! name: 'task1', project: project1, account: account1 }
    let(:manager1) { Manager.create! name: 'manager1', account: account1, tasks: [task1] }

    MultiTenant.with(account1) do
        expect(manager1.tasks.first.account_id).to eq(task1.account_id) # true
    end

Using ``activerecord-multi-tenant`` with Controllers
-----------------------------------------------------

When using ``activerecord-multi-tenant`` with controllers, you need to set the current tenant in the controller
before executing queries. You can do this by overriding the ``set_current_tenant`` method in your controller:

.. code-block:: ruby

    class ApplicationController < ActionController::Base
      set_current_tenant_through_filter # Required to opt into this behavior
      before_action :set_customer_as_tenant

      def set_customer_as_tenant
        customer = Customer.find(session[:current_customer_id])
        set_current_tenant(customer)
      end
    end

Best Practices and Recommendations
-----------------------------------

When using ``activerecord-multi-tenant``, keep the following best practices in mind:

- Always set the current tenant before executing queries in a multitenant context.
- Be mindful of the tenant scope when writing complex queries or joins.
- If you prefer not to set a tenant for the global context, but need to specify one for certain sections of code,
  you can utilize the `MultiTenant.with(tenant)` function. This will assign the `tenant` value
  to the specific code block where it's used.
