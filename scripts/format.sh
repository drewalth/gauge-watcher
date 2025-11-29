#!/usr/bin/env sh
#
# Format the code in the project.
#
# This script uses SwiftFormat to format the code in the project.
#
# It uses the .swiftformat file to configure the formatting.
#
# It uses the .swiftlint.yml file to configure the linting.
#
# It uses the .gitignore file to ignore the files that are not needed.
#
# It uses the .dockerignore file to ignore the files that are not needed.

swiftformat . --config airbnb.swiftformat
swiftlint . --config .swiftlint.yml --fix --format