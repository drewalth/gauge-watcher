// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AppDatabase",
  platforms: [
    .iOS(.v26),
    .macOS(.v15),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "AppDatabase",
      targets: ["AppDatabase"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
    .package(name: "GaugeSources", path: "../GaugeSources"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "AppDatabase",
      dependencies: [
        .product(name: "SQLiteData", package: "sqlite-data"),
        "GaugeSources",
      ]),
    .testTarget(
      name: "AppDatabaseTests",
      dependencies: ["AppDatabase"]),
  ])
