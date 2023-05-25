.. _troubleshooting:

Troubleshooting
===============

This section provides solutions to common issues you might encounter when using ``activerecord-multi-tenant``.

Common Issues and Their Solutions
---------------------------------

**Issue:** Tenant scope is not applied to queries.

**Solution:** Make sure you've set the current tenant before executing queries. Use the ``current_tenant`` class attribute to set the current tenant:

.. code-block:: ruby

   ActiveRecord::Multitenant.current_tenant = Company.first

**Issue:** Data leaks between tenants.

**Solution:** Be careful when using the ``ignore_tenant`` method, as it can lead to data leaks between tenants. Use it sparingly and only when necessary.

FAQs and Known Limitations
--------------------------

**Q: Can I use multiple tenant models in the same application?**

**A:** Yes, you can declare different tenant models in different ActiveRecord models. However, you can only set one current tenant at a time.

**Q: Does ``activerecord-multi-tenant`` support Rails version X?**

**A:** ``activerecord-multi-tenant`` supports Rails 6.0.0 and later. For older versions of Rails, please use the appropriate version of the gem.

Reporting Bugs and Requesting Features
--------------------------------------

If you encounter a bug or have a feature request, please open an issue on the `activerecord-multi-tenant GitHub repository <https://github.com/your-github-account/activerecord-multi-tenant/issues>`_. Please provide as much detail as possible so we can address the issue effectively.
