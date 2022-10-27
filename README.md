# activerecord-multi-tenant [ ![](https://img.shields.io/gem/v/activerecord-multi-tenant.svg)](https://rubygems.org/gems/activerecord-multi-tenant) [ ![](https://img.shields.io/gem/dt/activerecord-multi-tenant.svg)](https://rubygems.org/gems/activerecord-multi-tenant)

Introduction Post: https://www.citusdata.com/blog/2017/01/05/easily-scale-out-multi-tenant-apps/

ActiveRecord/Rails integration for multi-tenant databases, in particular the open-source [Citus](https://github.com/citusdata/citus) extension for PostgreSQL.

Enables easy scale-out by adding the tenant context to your queries, enabling the database (e.g. Citus) to efficiently route queries to the right database node.

## Installation

Add the following to your Gemfile:

```ruby
gem 'activerecord-multi-tenant'
```

## Supported Rails versions

All Ruby on Rails versions starting with 5.2 or newer (up to 7.0) are supported.

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

## Rolling out activerecord-multi-tenant for your application (write-only mode)

The library relies on tenant_id to be present and NOT NULL for all rows. However,
its often useful to have the library set the tenant_id for new records, and then backfilling
tenant_id for existing records as a background task.

To support this, there is a write-only mode, in which tenant_id is not included in queries,
but only set for new records. Include the following in an initializer to enable it:

```ruby
MultiTenant.enable_write_only_mode
```

Once you are ready to enforce tenancy, make your tenant_id column NOT NULL and simply remove that line.

## Frequently Asked Questions

* **What if I have a table that doesn't relate to my tenant?** (e.g. templates that are the same in every account)

  We recommend not using activerecord-multi-tenant on these tables. In case only some records in a table are not associated to a tenant (i.e. your templates are in the same table as actual objects), we recommend setting the tenant_id to 0, and then using MultiTenant.with(0) to access these objects.

* **What if my tenant model is not defined in my application?**

  The tenant model does not have to be defined. Use the gem as if the model was present. `MultiTenant.with` accepts either a tenant id or model instance.

## Credits

This gem was initially based on [acts_as_tenant](https://github.com/ErwinM/acts_as_tenant), and still shares some code. We thank the authors for their efforts.

## License

Copyright (c) 2018, Citus Data Inc.<br>
Licensed under the MIT license, see LICENSE file for details.
