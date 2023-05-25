.. _guides-and-tutorials:

Guides and Tutorials
====================

This section provides step-by-step guides and tutorials on how to use ``activerecord-multi-tenant`` in various scenarios.

Setting Up Multi tenancy in a New Project
------------------------------------------

To set up multitenancy in a new Rails project, follow these steps:

1. Install the ``activerecord-multi-tenant`` gem as described in the :ref:`getting-started` section.

2. Declare your tenant model in your ActiveRecord models:

   .. code-block:: ruby

      class User < ActiveRecord::Base
        multitenant :company
      end

3. Set the current tenant before executing queries:

   .. code-block:: ruby

      ActiveRecord::Multitenant.current_tenant = Company.first
      @users = User.all

Migrating an Existing Project to Use ``activerecord-multi-tenant``
------------------------------------------------------------------

If you have an existing Rails project and you want to add multitenancy support, follow these steps:

1. Install the ``activerecord-multi-tenant`` gem as described in the :ref:`getting-started` section.

2. Update your ActiveRecord models to declare the tenant model:

   .. code-block:: ruby

      class User < ActiveRecord::Base
        multitenant :company
      end

3. Update your application logic to set the current tenant before executing queries.

Best Practices and Recommendations
-----------------------------------

When using ``activerecord-multi-tenant``, keep the following best practices in mind:

- Always set the current tenant before executing queries in a multitenant context.
- Be mindful of the tenant scope when writing complex queries or joins.
- Use the ``ignore_tenant`` method sparingly, as it can lead to data leaks between tenants.
