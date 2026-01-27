// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let dependencies: [Target.Dependency] = [
    .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
    .product(name: "Logging", package: "swift-log"),
    .product(name: "Yams", package: "Yams"),
    .product(name: "AnyCodable", package: "AnyCodable")
]

let package = Package(
    name: "PluginSupport",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "PluginSupport",
            targets: ["PluginSupport"]
        ),
        .library(
            name: "PluginSupportStatic",
            targets: ["PluginSupportStatic"]
        ),
        .library(
            name: "PluginSupportTesting",
            targets: ["PluginSupportTesting"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/geko-tech/project-description", branch: "release/1.0.0"),
        .package(url: "https://github.com/apple/swift-tools-support-core", from: "0.6.1"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.3"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.15.1"),
        .package(url: "https://github.com/jpsim/Yams", exact: "5.0.6"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.7"),
    ],
    targets: [
        .target(
            name: "PluginSupport",
            dependencies: dependencies + [
                .product(name: "ProjectDescription", package: "project-description"),
                .product(name: "Crypto", package: "swift-crypto")
            ],
            cSettings: [.define("_GNU_SOURCE", .when(platforms: [.linux]))]
        ),
        .target(
            name: "PluginSupportStatic",
            dependencies: dependencies + [
                .product(name: "ProjectDescriptionStatic", package: "project-description"),
                .product(name: "Crypto", package: "swift-crypto")
            ],
            cSettings: [.define("_GNU_SOURCE", .when(platforms: [.linux]))]
        ),
        .target(
            name: "PluginSupportTesting",
            dependencies: [
                "PluginSupport",
            ],
            linkerSettings: [.linkedFramework("XCTest")]
        ),
        .testTarget(
            name: "PluginSupportTests",
            dependencies: ["PluginSupport"]
        ),
    ]
)
