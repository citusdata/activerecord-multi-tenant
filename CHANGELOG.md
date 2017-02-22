# Changelog

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
