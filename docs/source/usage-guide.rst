.. _usage-guide:

Usage Guide
===========

This section provides a comprehensive guide on how to use ``activerecord-multi-tenant`` in your Rails application.

Basic Usage
-----------

To use ``activerecord-multi-tenant``, you need to declare the tenant model in your ActiveRecord models. Here's an example:

.. code-block:: ruby

   class User < ActiveRecord::Base
     multi_tenant :company
   end

In this example, the ``User`` model is scoped to the ``Company`` model. This means that each user belongs to a specific company.

Multitenancy Concepts and Terminology
-------------------------------------

Multitenancy is a software architecture in which a single instance of software serves multiple tenants. A tenant is a group of users who share a common access with specific privileges to the software instance.

In the context of ``activerecord-multi-tenant``, a tenant is typically represented by a model in your Rails application (e.g., ``Company``), and other models (e.g., ``User``) are scoped to this tenant model.

Configuration Options
---------------------

``activerecord-multi-tenant`` provides several configuration options to customize its behavior:

- ``default_tenant``: Sets the default tenant for your application.
- ``ignore_tenant``: Ignores the tenant scope for specific queries.

Here's an example of how to use these options:

.. code-block:: ruby

   ActiveRecord::Multitenant.default_tenant = Company.first
   User.ignore_tenant do
     # This query will ignore the tenant scope
     @users = User.all
   end

Using Multitenancy with ActiveRecord Models
-------------------------------------------

When you've declared a tenant model using the ``multitenant`` method, you can scope your queries to the current tenant:

.. code-block:: ruby

   # Set the current tenant
   ActiveRecord::Multitenant.current_tenant = Company.first

   # This query will be scoped to the current tenant
   @users = User.all

Remember to always set the current tenant before executing queries in a multitenant context.
