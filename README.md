## activerecord-multi-tenant

ActiveRecord/Rails integration for multi-tenant databases, in particular the Citus extension for PostgreSQL.

### Installation

Add the following to your Gemfile:

```ruby
gem 'activerecord-multi-tenant'
```

### Supported Rails versions

All Ruby on Rails versions starting with 3.1 or newer are supported.

This gem only supports ActiveRecord (the Rails default ORM), and not alternative ORMs like Sequel.

### Usage

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

This gem is based on [acts_as_tenant](https://github.com/ErwinM/acts_as_tenant) and extends it to implement full support for mulit-tenant databases like Citus.

You can also use `acts_as_tenant` [own methods](https://github.com/ErwinM/acts_as_tenant#setting-the-current-tenant) to set the current tenant, but note that the model always has to be setup by `multi_tenant`.

### License

Licensed under the MIT license<br>
Copyright (c) 2016, Citus Data Inc.
