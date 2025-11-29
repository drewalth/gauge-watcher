#!/usr/bin/env sh
#
# Lint the code in the project.
#
# This script uses SwiftLint to lint the code in the project.
#
# It uses the .swiftlint.yml file to configure the linting.
#
# It uses the .gitignore file to ignore the files that are not needed.
#
# It uses the .dockerignore file to ignore the files that are not needed.

swiftlint . --config .swiftlint.yml