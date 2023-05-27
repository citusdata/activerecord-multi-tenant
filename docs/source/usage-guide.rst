.. _usage-guide:

Usage Guide
===========

This section provides a comprehensive guide on how to use ``activerecord-multi-tenant`` in your Rails application.

Basic Usage
-----------

To use ``activerecord-multi-tenant``, you need to declare the tenant model in your ActiveRecord models. Here's an example:

.. code-block:: ruby

    class PageView < ActiveRecord::Base
      multi_tenant :customer
      belongs_to :site

      # ...
    end

    class Site < ActiveRecord::Base
      multi_tenant :customer
      has_many :page_views

      # ...
    end

In this example, the ``PageView`` and ``Site`` models are scoped to the ``Customer`` model. This means that each user belongs to a specific customer.


Then wrap all code that runs queries/modifications in blocks like this:

.. code-block:: ruby

    customer = Customer.find(session[:current_customer_id])
    # ...
    MultiTenant.with(customer) do
      site = Site.find(params[:site_id])
      site.update! last_accessed_at: Time.now
      site.page_views.count
    end

Alternatively, if you don't want to use a block, you can set the current tenant explicitly:

.. code-block:: ruby

    customer = Customer.find(session[:current_customer_id])
    MultiTenant.current_tenant = customer


Multi-tenancy Concepts and Terminology
--------------------------------------

Multi-tenancy is a software architecture in which a single instance of software serves multiple tenants. A tenant is a group of users who share a common access with specific privileges to the software instance.

In the context of ``activerecord-multi-tenant``, a tenant is typically represented by a model in your Rails application (e.g., ``Customer``), and other models (e.g., ``PageView``) are scoped to this tenant model.


