// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "GaugeService",
  platforms: [
    .iOS(.v26),
    .macOS(.v15),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "GaugeService",
      targets: ["GaugeService"]),
  ],
  dependencies: [
    .package(name: "GaugeSources", path: "../GaugeSources"),
    .package(name: "AppDatabase", path: "../AppDatabase"),
    .package(name: "GaugeDrivers", path: "../GaugeDrivers"),
    .package(name: "FlowForecast", path: "../server/flow-forecast/sdks/FlowForecast"),
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.1"),
    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "GaugeService",
      dependencies: [
        "GaugeSources",
        "AppDatabase",
        "GaugeDrivers",
        "FlowForecast",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SQLiteData", package: "sqlite-data"),
      ]),
    .testTarget(
      name: "GaugeServiceTests",
      dependencies: ["GaugeService"]),
  ])
