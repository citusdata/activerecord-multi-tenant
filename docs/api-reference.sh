#!/bin/bash

# This script is used to generate the API reference documentation for the
# project. It is intended to be run from the root of the project directory.
# It requires the following tools to be installed:
# - yard (gem install yard)
echo "Generating API reference documentation..."
echo "Pwd: $(pwd)"
cd ..
yard doc --output-dir docs/source/_static/api-reference
