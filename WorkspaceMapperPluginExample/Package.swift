// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WorkspaceMapperExample",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "WorkspaceMapperExample",
            type: .dynamic,
            targets: ["WorkspaceMapperExample"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/geko-tech/ProjectDescription", branch: "release/1.0.0")
    ],
    targets: [
        .target(
            name: "WorkspaceMapperExample",
            dependencies: [
                .product(name: "ProjectDescription", package: "ProjectDescription"),
                "ProjectDescriptionHelpers"
            ],
        ),
        .target(
            name: "ProjectDescriptionHelpers",
            dependencies: [
                .product(name: "ProjectDescription", package: "ProjectDescription"),
            ],
            path: "ProjectDescriptionHelpers"
        )
    ]
)
