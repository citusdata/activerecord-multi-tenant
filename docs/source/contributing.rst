.. _contributing:

Contributing
============

We welcome contributions to ``activerecord-multi-tenant``! This section provides guidelines for contributing to the project.

Overview of the Development Process
-----------------------------------

``activerecord-multi-tenant`` is developed using a standard fork and pull request model. The `activerecord-multi-tenant GitHub repository <https://github.com/citusdata/activerecord-multi-tenant>`_ is the starting point for code contributions.

Guidelines for Contributing
---------------------------

1. **Fork the Repository:** Start by forking the official ``activerecord-multi-tenant`` repository to your own GitHub account.

2. **Clone the Repository:** Clone the forked repository to your local machine and add the official repository as an upstream remote:

   .. code-block:: bash

      $ git clone https://github.com/citusdata/activerecord-multi-tenant.git
      $ cd activerecord-multi-tenant
      $ git remote add upstream https://github.com/your-github-account/activerecord-multi-tenant.git

3. **Create a Feature Branch:** Create a new branch for each feature or bugfix:

   .. code-block:: bash

      $ git checkout -b my-feature-branch

4. **Commit Your Changes:** Make your changes and commit them to your feature branch.

5. **Push to GitHub:** Push your changes to your fork on GitHub:

   .. code-block:: bash

      $ git push origin my-feature-branch

6. **Submit a Pull Request:** Open a pull request from your feature branch to the master branch of the official ``activerecord-multi-tenant`` repository.

Please ensure your code adheres to the existing style conventions of the project. Include tests for any new features or bug fixes, and update the documentation as necessary.

Setting Up a Development Environment
------------------------------------

To set up a development environment for ``activerecord-multi-tenant``, follow these steps:

1. Clone the repository as described in the contributing guidelines.

2. Install the required dependencies:

   .. code-block:: bash

      $ bundle install

3. Run the tests to ensure everything is set up correctly:

   .. code-block:: bash

      $ bundle exec rake spec
