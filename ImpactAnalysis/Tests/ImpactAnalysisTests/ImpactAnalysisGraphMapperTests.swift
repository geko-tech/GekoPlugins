import Foundation
import XCTest
import ProjectDescription
import PluginSupportTesting
import ProjectDescriptionHelpers
@testable import ImpactAnalysis

final class ImpactAnalysisGraphMapperTests: GekoPluginTestCase {
    func test_example() async throws {
        // given
        let workspacePath = try temporaryPath()

        let environment = MockEnvironment()
        let system = MockSystem()

        let subject = ImpactAnalysisWorkspaceMapper(
            environment: environment,
            system: system
        )

        var sideTable = WorkspaceSideTable()

        func set(_ flags: TargetFlags, path: AbsolutePath, name: String) {
            sideTable.projects[path, default: .init()]
                .targets[name, default: .init()].flags = flags
        }
        func setSourcesGlobs(_ sources: [SourceFiles], path: AbsolutePath, name: String) {
            sideTable.projects[path, default: .init()]
                .targets[name, default: .init()].sources = sources
        }

        let aProjectPath = workspacePath.appending(component: "CoreFramework")
        let bProjectPath = workspacePath.appending(component: "Framework1")
        let cProjectPath = workspacePath.appending(component: "Framework2")
        let dProjectPath = workspacePath.appending(component: "Framework3")
        let eProjectPath = workspacePath.appending(component: "Framework4")
        let fProjectPath = workspacePath.appending(component: "Framework5")
        let gProjectPath = workspacePath.appending(component: "Framework6")
        let sharedTargetProjectPath = workspacePath.appending(component: "SharedTarget")
        
        let aSourceFilePath = aProjectPath.appending(components: "Sources", "File.swift")
        let aTarget = Target.test(
            name: "CoreFramework", product: .staticFramework,
            sources: [
                SourceFiles(paths: [aSourceFilePath])
            ]
        )
        let aDependency: TargetDependency = .project(target: aTarget.name, path: aProjectPath)
        let aTargetTests = Target.test(
            name: "CoreFramework-Unit-Tests", product: .unitTests,
            dependencies: [aDependency]
        )
        let aTargetTestsFramework = Target.test(
            name: "CoreFramework-Unit-TestsGekoGenerated", product: .staticFramework,
            dependencies: [aDependency]
        )
        let aProject = Project.test(
            path: aProjectPath, name: "CoreFramework",
            targets: [aTarget, aTargetTests, aTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: aProjectPath, name: aTargetTestsFramework.name)

        let bTarget = Target.test(
            name: "Framework1", product: .staticFramework,
            dependencies: [aDependency]
        )
        let bDependency: TargetDependency = .project(target: bTarget.name, path: bProjectPath)
        let bTargetTests = Target.test(
            name: "Framework1-Unit-Tests", product: .unitTests,
            dependencies: [bDependency]
        )
        let bTargetTestsFramework = Target.test(
            name: "Framework1-Unit-TestsGekoGenerated", product: .staticFramework,
            dependencies: [bDependency]
        )
        let bProject = Project.test(
            path: bProjectPath, name: "Framework1",
            targets: [bTarget, bTargetTests, bTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: bProjectPath, name: bTargetTestsFramework.name)

        let cTarget = Target.test(
            name: "Framework2",
            product: .staticFramework,
            dependencies: [aDependency]
        )
        let cDependency: TargetDependency = .project(target: cTarget.name, path: cProjectPath)
        let cTargetTests = Target.test(
            name: "Framework2-Unit-Tests", product: .unitTests,
            dependencies: [cDependency]
        )
        let cTargetTestsFramework = Target.test(
            name: "Framework2-Unit-TestsGekoGenerated", product: .staticFramework,
            dependencies: [cDependency]
        )
        let cProject = Project.test(
            path: cProjectPath, name: "Framework2",
            targets: [cTarget, cTargetTests, cTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: cProjectPath, name: cTargetTestsFramework.name)

        let dTarget = Target.test(name: "Framework3", product: .staticFramework)
        let dDependency: TargetDependency = .project(target: dTarget.name, path: dProjectPath)
        let dTargetTests = Target.test(
            name: "Framework3-Unit-Tests", product: .unitTests,
            dependencies: [dDependency]
        )
        let dTargetTestsFramework = Target.test(
            name: "Framework3-Unit-TestsGekoGenerated", product: .staticFramework,
            dependencies: [dDependency]
        )
        let dProject = Project.test(
            path: dProjectPath, name: "Framework3",
            targets: [dTarget, dTargetTests, dTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: dProjectPath, name: dTargetTestsFramework.name)

        let eResourceFilePath = eProjectPath.appending(components: "Resources", "image.png")
        let eTarget = Target.test(
            name: "Framework4", product: .framework,
            resources: [
                .file(path: eResourceFilePath)
            ]
        )
        let eDependency: TargetDependency = .project(target: eTarget.name, path: eProjectPath)
        let eTargetTests = Target.test(
            name: "Framework4-Unit-Tests", product: .unitTests,
            dependencies: [eDependency]
        )
        let eTargetTestsFramework = Target.test(
            name: "Framework4-Unit-TestsGekoGenerated", product: .staticFramework,
            dependencies: [eDependency]
        )
        let eProject = Project.test(
            path: eProjectPath, name: "Framework4",
            targets: [eTarget, eTargetTests, eTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: eProjectPath, name: eTargetTestsFramework.name)

        let fTarget = Target.test(name: "Framework5", product: .staticFramework)
        let fDependency: TargetDependency = .project(target: fTarget.name, path: fProjectPath)
        let fTargetTests = Target.test(
            name: "Framework5-Unit-Tests", product: .unitTests,
            dependencies: [fDependency]
        )
        let fTargetTestsFramework = Target.test(
            name: "Framework5-Unit-TestsGekoGenerated", product: .staticFramework,
            dependencies: [fDependency]
        )
        let fProject = Project.test(
            path: fProjectPath, name: "Framework5",
            targets: [fTarget, fTargetTests, fTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: fProjectPath, name: fTargetTestsFramework.name)
        
        let gSourceFilePath = gProjectPath.appending(components: "Sources", "File6.swift")
        let gSourceFilesGlob = SourceFiles(paths: [FilePath("\(workspacePath)/Framework6/Sources/**/*.swift")])
        let gTarget = Target.test(name: "Framework6", product: .staticFramework)
        let gDependency: TargetDependency = .project(target: gTarget.name, path: gProjectPath)
        let gTargetTests = Target.test(
            name: "Framework6-Unit-Tests", product: .unitTests,
            dependencies: [gDependency]
        )
        let gTargetTestsFramework = Target.test(
            name: "Framework6-Unit-TestsGekoGenerated", product: .staticFramework,
            dependencies: [gDependency]
        )
        let gProject = Project.test(
            path: gProjectPath, name: "Framework6",
            targets: [gTarget, gTargetTests, gTargetTestsFramework]
        )
        set(.sharedTestTargetGeneratedFramework, path: gProjectPath, name: gTargetTestsFramework.name)
        setSourcesGlobs([gSourceFilesGlob], path: gProjectPath, name: gTarget.name)

        let sharedTarget = Target.test(
            name: "SharedTarget", product: .unitTests,
            dependencies: [
                // SharedTarget -> CoreFramework-Unit-TestsGekoGenerated
                .project(target: aTargetTestsFramework.name, path: aProjectPath),
                // SharedTarget -> Framework1-Unit-TestsGekoGenerated
                .project(target: bTargetTestsFramework.name, path: bProjectPath),
                // SharedTarget -> Framework2-Unit-TestsGekoGenerated
                .project(target: cTargetTestsFramework.name, path: cProjectPath),
                // SharedTarget -> Framework3-Unit-TestsGekoGenerated
                .project(target: dTargetTestsFramework.name, path: dProjectPath),
                // SharedTarget -> Framework4-Unit-TestsGekoGenerated
                .project(target: eTargetTestsFramework.name, path: eProjectPath),
                // SharedTarget -> Framework5-Unit-TestsGekoGenerated
                .project(target: fTargetTestsFramework.name, path: fProjectPath),
                // SharedTarget -> Framework6-Unit-TestsGekoGenerated
                .project(target: gTargetTestsFramework.name, path: gProjectPath),
            ]
        )
        let sharedTargetProject = Project.test(
            path: sharedTargetProjectPath, name: "SharedTarget",
            targets: [sharedTarget]
        )
        set(.sharedTestTarget, path: sharedTargetProjectPath, name: sharedTarget.name)
        
        var workspace = WorkspaceWithProjects(
            workspace: .test(
                path: workspacePath,
                xcWorkspacePath: workspacePath,
                projects: [
                    aProjectPath,
                    bProjectPath,
                    cProjectPath,
                    dProjectPath,
                    eProjectPath,
                    fProjectPath,
                    gProjectPath,
                    sharedTargetProjectPath,
                ],
            ),
            projects: [
                aProject,
                bProject,
                cProject,
                dProject,
                eProject,
                fProject,
                gProject,
                sharedTargetProject,
            ]
        )

        var externalDependenciesGraph = DependenciesGraph(
            externalDependencies: ["VeryCoolPod": [.project(target: aTarget.name, path: aProjectPath)]],
            externalProjects: [:],
            externalFrameworkDependencies: [:],
            tree: [:]
        )

        environment.impactTargetRef = "targetRef"
        environment.impactAnalysisChangedTargets = [fTarget.name]
        system.succeedCommand(
            ["git", "diff", "targetRef...HEAD", "--name-only", "--no-renames", "--diff-filter=d"],
            output: """
                Geko/Dependencies/Cocoapods.lock
                \(eResourceFilePath.relative(to: workspacePath))
                """
        )
        system.succeedCommand(
            ["git", "diff", "targetRef...HEAD", "--name-only", "--no-renames", "--diff-filter=D"],
            output: """
                \(gSourceFilePath.relative(to: workspacePath))
                """
        )

        let oldLockfile = """
            https://cocoapods-cdn.company.com/private-specs/:
              pods:
                VeryCoolPod:
                  hash: b0dfe3d9b1834aa3827b1211a48b4a60e007c965
                  version: 1.5.0

              type: cdn
            """
        
        let newLockfile = """
            https://cocoapods-cdn.company.com/private-specs/:
              pods:
                VeryCoolPod:
                  hash: b1dfe3d9b1834aa3827b1211a48b4a60e007c965
                  version: 1.6.0

              type: cdn
            """

        system.succeedCommand(
            ["git", "show", "targetRef:Geko/Dependencies/Cocoapods.lock"], output: oldLockfile
        )
        system.succeedCommand(
            ["git", "show", "HEAD:Geko/Dependencies/Cocoapods.lock"], output: newLockfile
        )
        
        let gstt = GenerateSharedTestTarget(
            installTo: sharedTargetProject.name,
            targets: [
                .generate(name: "SharedTarget", testsPattern: ".*-Unit-Tests")
            ]
        )

        // When

        _ = try subject.map(
            workspace: &workspace,
            sideTable: &sideTable,
            externalDependenciesGraph: externalDependenciesGraph,
            gstt: gstt
        )

        // Then
        let target = try XCTUnwrap(
            workspace.projects.first(where: { $0.path == dProjectPath })?.targets.first(where: { $0.name == dTargetTestsFramework.name })
        )
        XCTAssertTrue(target.prune)

        let sharedTargetResult = try XCTUnwrap(
            workspace.projects.first(where: { $0.path == sharedTargetProjectPath })?.targets.first(where: {
                $0.name == sharedTarget.name
            })
        )
        XCTAssertEqual(
            sharedTargetResult.dependencies,
            [
                // SharedTarget -> CoreFramework-Unit-TestsGekoGenerated
                // because CoreFramework was changed in Cocoapods.lock
                .project(target: aTargetTestsFramework.name, path: aProjectPath),
                // SharedTarget -> Framework1-Unit-TestsGekoGenerated
                // because bTarget depends on CoreFramework whichwas changed
                .project(target: bTargetTestsFramework.name, path: bProjectPath),
                // SharedTarget -> Framework2-Unit-TestsGekoGenerated
                // because cTarget's source file was changed
                .project(target: cTargetTestsFramework.name, path: cProjectPath),
                // SharedTarget -> Framework4-Unit-TestsGekoGenerated
                // because eTarget's resource file was changed
                .project(target: eTargetTestsFramework.name, path: eProjectPath),
                // SharedTarget -> Framework5-Unit-TestsGekoGenerated
                // because fTarget was marked as changed through env var
                .project(target: fTargetTestsFramework.name, path: fProjectPath),
                // SharedTarget -> Framework6-Unit-TestsGekoGenerated
                // because gTarget's source file was deleted
                .project(target: gTargetTestsFramework.name, path: gProjectPath),
            ],
            "Dependency SharedTarget -> Framework3 must be removed from dependencies graph"
        )
    }
}
