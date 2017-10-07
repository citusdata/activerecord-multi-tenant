# Changelog

## 0.8.1       2017-10-06

* Cast attribute name to a string to avoid double applying tenant clause [Ben Olive](https://github.com/sionide21)
* Allow bulk delete/update with subqueries on joins [Kyle Bock](https://github.com/kwbock)


## 0.8.0       2017-08-16

* Significant improvements and simplifications of query rewriting
  * Big thanks to [Kyle Bock](https://github.com/kwbock) and [Ben Olive](https://github.com/sionide21)
    for (re-)writing this code and verifying it works well
  * This fixes caching issues across multiple MultiTenant.with { } blocks when
    interacting with the Rails statement cache
* Drop support for Rails 3.2
  * The arel version used in Rails 3.2 has caused more trouble than its worth -
    it seems less troublesome to ask any users of this library to upgrade to at
    least Rails 4.0


## 0.7.0       2017-07-18

* Switch back to Relation-based mechanism of hooking into ActiveRecord (this resolves issues for simple queries that didn't get rewritten)
* Query rewriter improvements
  * Handle OUTER JOIN correctly
  * Correctly rewrite sub-selects
* Model tenant method: Only return cached object if not loaded
* Fix support for inherited model classes that only have `multi-tenant` on a higher level object [Aaron Severs](https://github.com/webandtech) [#13](https://github.com/citusdata/activerecord-multi-tenant/pull/13)
* Sidekiq middleware: Don't automatically perform a find for the tenant object for every job [Scott Mitchell](https://github.com/smitchelus) [#14](https://github.com/citusdata/activerecord-multi-tenant/pull/14)
* Fix automatic inverse of on singular associations [Kyle Bock](https://github.com/kwbock) [#15](https://github.com/citusdata/activerecord-multi-tenant/pull/15)
* Fix bug that prevents fast truncate from running [Kyle Bock](https://github.com/kwbock) [#17](https://github.com/citusdata/activerecord-multi-tenant/pull/17)


## 0.6.0       2017-06-09

* Query rewriter
  * Change hook from per-relation to be pre-SQL statement thats being output
    - This should resolve issues where we added conditions in the wrong place
  * Use table name to model klass registry
* Improve tests for activerecord-multi-tenant
  * Use lower shard count to speed up tests
  * Drop database cleaner dependency


## 0.5.0       2017-05-08

* Write-only mode that enables step-by-step migrations
* Add tenant_id to queries using rewrite instead of default_scope/unscoped [Ben Olive](https://github.com/sionide21)
* Query monitor that warns you about missing tenant_id
* Helper for fast truncation
* Sidekiq middleware


## 0.4.1       2017-03-23

* Allow use outside of Rails, e.g. when using Sinatra with ActiveRecord [@nathanstitt](https://github.com/nathanstitt) [#5](https://github.com/citusdata/activerecord-multi-tenant/pull/5)


## 0.4.0       2017-03-22

* Infer multi_tenant setting from parent classes [@webandtech](https://github.com/webandtech) [#6](https://github.com/citusdata/activerecord-multi-tenant/pull/6)
* Remove use of global tenant klass variable [@webandtech](https://github.com/webandtech) [#6](https://github.com/citusdata/activerecord-multi-tenant/pull/6)
* Support passing ID values to MultiTenant.with directly [@webandtech](https://github.com/webandtech) [#6](https://github.com/citusdata/activerecord-multi-tenant/pull/6)
  * This effectively deprecates with_id, but we'll keep it around for now
* Remove unnecessary validation for invalid belongs_to association


## 0.3.4       2017-02-22

* Expand with_lock workaround to cover lock! as well
* Enable trigger workaround on Rails 5 as well, otherwise it fails silently
* Tests: Switch to database cleaner truncation strategy to avoid multi-shard transactions


## 0.3.3       2017-02-21

* Avoid warning about multi-column primary keys with Rails 5 [#2](https://github.com/citusdata/activerecord-multi-tenant/issues/2)
* Fix odd bind errors for has_one/has_many through
* Add MultiTenant.current_tenant_id= helper method


## 0.3.2       2017-02-16

* Support blocks passed into the unscoped method (this fixes reload, amongst other issues)
* Make with_lock work by adding workaround for Citus #1236 (SELECT ... FOR UPDATE is not router-plannable)


## 0.3.1       2017-02-13

* Rails 5 API controller support [@mstahl](https://github.com/mstahl) [#4](https://github.com/citusdata/activerecord-multi-tenant/pull/4)
* Citus 6.1 compatibility


## 0.3.0       2016-12-30

* Remove dependency on acts_as_tenant - instead copy the code thats necessary
* Fix issue with callbacks having TenantIdWrapper instead of the actual object


## 0.2.1       2016-12-29

* Fix bug in CopyFromClient helper


## 0.2.0       2016-12-27

* Initial release
