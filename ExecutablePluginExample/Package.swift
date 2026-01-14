// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RemotePlugin",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "ExampleGekoExecutable",
            targets: ["ExampleTarget"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ExampleTarget",
            dependencies: []
        ),
    ]
)