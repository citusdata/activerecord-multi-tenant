.. _getting-started:

Getting Started
===============

This section will guide you through the process of installing and setting up ``activerecord-multitenant`` in your Rails application.

Installation
------------

To install ``activerecord-multitenant``, add the following line to your application's Gemfile:

.. code-block:: ruby

   gem install activerecord-multi-tenant

Then execute:

.. code-block:: bash

   $ bundle install

Or install it yourself as:

.. code-block:: bash

   $ gem install activerecord-multi-tenant

Configuration
-------------

After installing the gem, you need to configure it to work with your application. Here's a basic example of how to set up a multitenant model:

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

In this example, the ``PageView`` model is scoped to the ``Customer`` model, meaning that each page view belongs to a specific customer.

Dependencies
------------

``activerecord-multitenant`` requires:

- Ruby version 3.0.0 or later
- Rails version 6.0.0 or later

Please ensure that your application meets these requirements before installing the gem.

---

Remember, this is just a draft, and you can modify or expand it according to your project's specific needs. The code snippets and version requirements are placeholders and should be replaced with the actual code and requirements for your project.