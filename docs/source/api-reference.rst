.. _api-reference:

API Reference
=============

This section provides a detailed overview of the available classes, modules, and methods in the ``activerecord-multi-tenant`` gem.

Overview
--------

``activerecord-multi-tenant`` extends ActiveRecord with the ability to scope models to a tenant. The main components of the gem are:

- The ``multitenant`` class method
- The ``current_tenant`` class attribute
- The ``ignore_tenant`` class method

``multitenant`` Class Method
----------------------------

The ``multitenant`` class method is used to declare a tenant model in an ActiveRecord model.

.. code-block:: ruby

   class User < ActiveRecord::Base
     multitenant :company
   end

``current_tenant`` Class Attribute
----------------------------------

The ``current_tenant`` class attribute is used to set and get the current tenant.

.. code-block:: ruby

   # Set the current tenant
   ActiveRecord::Multitenant.current_tenant = Company.first

   # Get the current tenant
   current_tenant = ActiveRecord::Multitenant.current_tenant

``ignore_tenant`` Class Method
------------------------------

The ``ignore_tenant`` class method is used to ignore the tenant scope for specific queries.

.. code-block:: ruby

   User.ignore_tenant do
     # This query will ignore the tenant scope
     @users = User.all
   end
