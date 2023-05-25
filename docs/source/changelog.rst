. _changelog:

Changelog
=========

This section provides a history of changes for each version of ``activerecord-multi-tenant``.
For a complete history of changes, please refer to the official changelog on GitHub <https://github.com/citusdata/activerecord-multi-tenant/blob/master/CHANGELOG.md>_.

Version 1.1.0 (2023-05-23)
--------------------------

**New Features:**

- Added support for Rails 7.0.
- Introduced the ``ignore_tenant`` method to bypass the tenant scope for specific queries.

**Bug Fixes:**

- Fixed an issue where the tenant scope was not applied correctly in certain scenarios.

**Improvements:**

- Improved performance of tenant scoping queries.
- Updated documentation with new guides and tutorials.

Version 1.0.0 (2023-04-01)
--------------------------

**New Features:**

- Initial release of ``activerecord-multi-tenant``.
- Added the ``multitenant`` class method to declare a tenant model in ActiveRecord models.
- Added the ``current_tenant`` class attribute to set and get the current tenant.
