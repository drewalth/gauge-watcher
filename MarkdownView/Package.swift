// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MarkdownView",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "MarkdownView",
      targets: ["MarkdownView"]),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "MarkdownView",
      path: "Sources/MarkdownView",
      exclude: [
        "Resources/main.js.LICENSE.txt",
      ],
      resources: [
        .copy("Resources/styled.html"),
        .copy("Resources/non_styled.html"),
        .copy("Resources/main.js"),
        .copy("Resources/main.css"),
      ]),
    .testTarget(
      name: "MarkdownViewTests",
      dependencies: ["MarkdownView"]),
  ])
