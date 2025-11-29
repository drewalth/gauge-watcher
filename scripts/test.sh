#!/usr/bin/env sh
#
# Test the code in the project.
#
# This script uses SwiftTest to test the code in the project.
#
# It uses the .swiftpackage.resolved file to resolve the dependencies.
#
# It uses the .gitignore file to ignore the files that are not needed.
#
# It uses the .dockerignore file to ignore the files that are not needed.

swift test --package-path ./GaugeSources
swift test --package-path ./GaugeDrivers