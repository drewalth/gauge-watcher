// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AppTelemetry",
  platforms: [
    .iOS(.v18),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "AppTelemetry",
      targets: ["AppTelemetry"]),
  ],
  dependencies: [
    .package(url: "https://github.com/PostHog/posthog-ios.git", from: "3.0.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "AppTelemetry",
      dependencies: [.product(name: "PostHog", package: "posthog-ios")]),
    .testTarget(
      name: "AppTelemetryTests",
      dependencies: ["AppTelemetry"]),
  ])
