// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImpactAnalysis",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "ImpactAnalysis",
            type: .dynamic,
            targets: ["ImpactAnalysis"]
        ),
    ],
    dependencies: [
        .package(path: "../PluginSupport")
    ],
    targets: [
        .testTarget(
            name: "ImpactAnalysisTests",
            dependencies: [
                "ImpactAnalysis",
                .product(name: "PluginSupportTesting", package: "PluginSupport"),
            ]
        ),
        .target(
            name: "ImpactAnalysis",
            dependencies: [
                .product(name: "PluginSupport", package: "PluginSupport"),
                "ProjectDescriptionHelpers"
            ],
        ),
        .target(
            name: "ProjectDescriptionHelpers",
            dependencies: [
                .product(name: "PluginSupport", package: "PluginSupport")
            ],
            path: "ProjectDescriptionHelpers",
        )
    ]
)
