## citus-rails

Work in progress :)

You can find the actual code in the branches, e.g. `rails-4.2`

### Installation

Add the following to your Gemfile:

```
gem 'citus-rails'
```

Note that this currently assumes you are using Rails 4.2.

### Usage

Annotate your models like this:

```ruby
class Click < ActiveRecord::Base
  self.primary_keys = :click_id, :ad_id

  acts_as_distributed partition_column: :ad_id

  ...
end
```

Note the multiple primary keys, powered by [composite_primary_keys](https://github.com/composite-primary-keys/composite_primary_keys), and the `acts_as_distributed` definition for specifying your Citus distribution/partition column.

### License

Licensed under the MIT license<br>
Copyright (c) 2016, Citus Data Inc.
