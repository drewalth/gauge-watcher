// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "UIComponents",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "UIComponents",
      targets: ["UIComponents"]),
  ],
  dependencies: [
    .package(url: "https://github.com/VakhoKontridze/VComponents", from: "7.2.5"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "UIComponents",
      dependencies: ["VComponents"]),
    .testTarget(
      name: "UIComponentsTests",
      dependencies: ["UIComponents"]),
  ])
