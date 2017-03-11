# activerecord-multi-tenant [ ![](https://img.shields.io/gem/v/activerecord-multi-tenant.svg)](https://rubygems.org/gems/activerecord-multi-tenant) [ ![](https://img.shields.io/gem/dt/activerecord-multi-tenant.svg)](https://rubygems.org/gems/activerecord-multi-tenant)

ActiveRecord/Rails integration for multi-tenant databases, in particular the Citus extension for PostgreSQL.

## Installation

Add the following to your Gemfile:

```ruby
gem 'activerecord-multi-tenant'
```

## Supported Rails versions

All Ruby on Rails versions starting with 3.2 or newer are supported.

This gem only supports ActiveRecord (the Rails default ORM), and not alternative ORMs like Sequel.

## Usage

It is required that you add `multi_tenant` definitions to your model in order to have full support for Citus, in particular when updating records.

In the example of an analytics application, sharding on `customer_id`, annotate your models like this:

```ruby
class PageView < ActiveRecord::Base
  multi_tenant :customer
  belongs_to :site

  # ...
end

class Site < ActiveRecord::Base
  multi_tenant :customer
  has_many :page_views
  belongs_to :customer

  # ...
end
```

and then wrap all code that runs queries/modifications in blocks like this:

```ruby
customer = Customer.find(session[:current_customer_id])
# ...
MultiTenant.with(customer) do
  site = Site.find(params[:site_id])
  site.update! last_accessed_at: Time.now
  site.page_views.count
end
```

Inside controllers you can use a before_action together with set_current_tenant, to set the tenant for the current request:

```ruby
class ApplicationController < ActionController::Base
  set_current_tenant_through_filter # Required to opt into this behavior
  before_action :set_customer_as_tenant

  def set_customer_as_tenant
    customer = Customer.find(session[:current_customer_id])
    set_current_tenant(customer)
  end
end
```

## Frequently Asked Questions

* **What if I have a table that doesn't relate to my tenant?** (e.g. templates that are the same in every account)

  We recommend not using activerecord-multi-tenant on these tables. In case only some records in a table are not associated to a tenant (i.e. your templates are in the same table as actual objects), we recommend setting the tenant_id to 0, and then using MultiTenant.with(0) to access these objects.

* **What if my tenant model is not defined in my application?**

  The tenant model does not have to be defined. Use the gem as if the model was present. `MultiTenant.with` accepts either a tenant id or model instance.

## Credits

This gem was initially based on [acts_as_tenant](https://github.com/ErwinM/acts_as_tenant), and still shares some code. We thank the authors for their efforts.

## License

Licensed under the MIT license<br>
Copyright (c) 2016, Citus Data Inc.
