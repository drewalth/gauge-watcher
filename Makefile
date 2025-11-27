pretty:
	@swiftformat . --config airbnb.swiftformat
	@swiftlint --config .swiftlint.yml --fix --format

lint:
	swiftlint . --config .swiftlint.yml

test_packages:
	swift test --package-path ./GaugeSources
	swift test --package-path ./GaugeDrivers

check_leaks:
	gitleaks detect --source . -v