import Foundation
import ProjectDescription

extension Target {
    /// Creates a Target with test data
    /// Note: Referenced paths may not exist
    public static func test(
        name: String = "Target",
        destinations: Destinations = [.iPhone, .iPad],
        product: Product = .app,
        productName: String? = nil,
        bundleId: String? = nil,
        deploymentTargets: DeploymentTargets = .iOS("13.1"),
        infoPlist: InfoPlist? = nil,
        entitlements: Entitlements? = nil,
        settings: Settings? = Settings.test(),
        sources: [SourceFiles] = [],
        resources: [ResourceFileElement] = [],
        copyFiles: [CopyFilesAction] = [],
        coreDataModels: [CoreDataModel] = [],
        headers: HeadersList? = nil,
        scripts: [TargetScript] = [],
        environmentVariables: [String: EnvironmentVariable] = [:],
        filesGroup: ProjectGroup = .group(name: "Project"),
        dependencies: [TargetDependency] = [],
        launchArguments: [LaunchArgument] = [],
        playgrounds: [AbsolutePath] = [],
        additionalFiles: [FileElement] = [],
        preCreatedFiles: [String] = [],
        mergedBinaryType: MergedBinaryType = .disabled,
        mergeable: Bool = false
    ) -> Target {
        Target(
            name: name,
            destinations: destinations,
            product: product,
            productName: productName,
            bundleId: bundleId ?? "io.tuist.\(name)",
            deploymentTargets: deploymentTargets,
            infoPlist: infoPlist,
            sources: .init(sourceFiles: sources),
            playgrounds: playgrounds,
            resources: .init(resources: resources),
            copyFiles: copyFiles,
            headers: headers,
            entitlements: entitlements,
            scripts: scripts,
            dependencies: dependencies,
            settings: settings,
            coreDataModels: coreDataModels,
            environmentVariables: environmentVariables,
            launchArguments: launchArguments,
            additionalFiles: additionalFiles,
            preCreatedFiles: preCreatedFiles,
            mergedBinaryType: mergedBinaryType,
            mergeable: mergeable,
            filesGroup: filesGroup
        )
    }
}
