# Changelog

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
