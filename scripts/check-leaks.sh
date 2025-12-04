#!/usr/bin/env sh
#
# Check for secrets/leaks in the code.
#
# This script uses gitleaks to check for secrets/leaks in the code.
#
# It uses the .gitignore file to ignore the files that are not needed.
#
# It uses the .dockerignore file to ignore the files that are not needed.

gitleaks detect --source . -v