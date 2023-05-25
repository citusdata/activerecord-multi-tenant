.. Django Multi-tenant documentation master file, created by
sphinx-quickstart on Mon Feb 13 13:32:28 2023.
You can adapt this file completely to your liking, but it should at least
contain the root `toctree` directive.

Welcome to ActiveRecord Multi-tenant's documentation!
=================================================

|Latest Documentation Status| |Build Status| |Coverage Status| |PyPI Version|

[TODO: Change documentation link to actual documentation link]
.. |Latest Documentation Status| image:: https://readthedocs.org/projects/django-multitenant/badge/?version=latest
    :target: https://django-multitenant.readthedocs.io/en/latest/?badge=latest
    :alt: Documentation Status

.. |Build Status| image:: https://github.com/citusdata/activerecord-multi-tenant/actions/workflows/active-record-multi-tenant-tests.yml/badge.svg
   :target: https://github.com/citusdata/activerecord-multi-tenant/actions/workflows/active-record-multi-tenant-tests.yml
   :alt: Build Status

.. |Coverage Status| image:: https://codecov.io/gh/citusdata/activerecord-multi-tenant/branch/master/graph/badge.svg?token=rw0TsEk4Ld
   :target: https://codecov.io/gh/citusdata/activerecord-multi-tenant
   :alt: Coverage Status

.. |RubyGems Version| image:: https://badge.fury.io/rb/activerecord-multi-tenant.svg
   :target: https://badge.fury.io/rb/activerecord-multi-tenant


ActiveRecord/Rails integration for multi-tenant databases, in particular the open-source Citus extension for PostgreSQL.

Enables easy scale-out by adding the tenant context to your queries, enabling the database (e.g. Citus) to efficiently route queries to the right database node.

.. toctree::
   :maxdepth: 2
   :caption: Table Of Contents

   general
   usage
   migration_mt_django
   django_rest_integration
   license
