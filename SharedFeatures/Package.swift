// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedFeatures",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "SharedFeatures",
            targets: ["SharedFeatures"]
        ),
    ],
    dependencies: [
        .package(name: "AppDatabase", path: "../AppDatabase"),
        .package(name: "GaugeService", path: "../GaugeService"),
        .package(name: "GaugeSources", path: "../GaugeSources"),
        .package(name: "GaugeDrivers", path: "../GaugeDrivers"),
        .package(name: "UIAppearance", path: "../UIAppearance"),
        .package(name: "UIComponents", path: "../UIComponents"),
        .package(name: "AppTelemetry", path: "../AppTelemetry"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.23.1"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
        .package(url: "https://github.com/drewalth/swift-loadable.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/drewalth/accessible-ui.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SharedFeatures",
            dependencies: [
                "AppDatabase",
                "GaugeService",
                "GaugeSources",
                "GaugeDrivers",
                "UIAppearance",
                "UIComponents",
                "AppTelemetry",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Loadable", package: "swift-loadable"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "AccessibleUI", package: "accessible-ui"),
            ]
        ),
        .testTarget(
            name: "SharedFeaturesTests",
            dependencies: ["SharedFeatures"]
        ),
    ]
)

