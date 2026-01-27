import Foundation
import struct ProjectDescription.AbsolutePath
import struct ProjectDescription.RelativePath
import struct ProjectDescription.FilePath
import struct ProjectDescription.WorkspaceWithProjects
import enum ProjectDescription.TargetDependency
import struct ProjectDescription.Project
import struct ProjectDescription.BuildableFolder
import enum ProjectDescription.SideEffectDescriptor
import struct ProjectDescription.SourceFiles
import struct ProjectDescription.DependenciesGraph
import struct ProjectDescription.CocoapodsLockfile
import PluginSupport
import ProjectDescriptionHelpers

private extension NSRegularExpression {
    static let workspaceRegex = try! NSRegularExpression(pattern: #"^Workspace(\+[A-Za-z0-9_]+)?\.swift$"#)
}

public final class ImpactAnalysisWorkspaceMapper {
    private var environment: Environmenting
    private var system: Systeming
    private var fileHandler: FileHandling
    private let globConverter: GlobConverter
    private var symlinks: [String: String]

    public init(
        environment: Environmenting = Environment.shared,
        system: Systeming = System.shared,
        fileHandler: FileHandling = FileHandler.shared,
        globConverter: GlobConverter = GlobConverter()
    ) {
        self.environment = environment
        self.system = system
        self.fileHandler = fileHandler
        self.globConverter = globConverter
        self.symlinks = environment.impactAnalysisSymlinksSupportEnabled ? SymlinksFinder().findSymlinks(in: fileHandler.currentPath.asURL) : [:]
    }
}

// MARK: - GraphMapping

extension ImpactAnalysisWorkspaceMapper {
    public func map(
        workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable,
        externalDependenciesGraph: DependenciesGraph,
        gstt: GenerateSharedTestTarget?
    ) throws -> [SideEffectDescriptor] {
        guard let gstt = gstt else { return [] }

        let installTo = gstt.installTo
        guard
            let project = workspace.projects
                .first(where: { project in project.name == installTo })
        else {
            fatalError("This should not be possible")
        }
        let projectPath = project.path

        let targetNames = project.targets
            .filter {
                sideTable.projects[projectPath]?.targets[$0.name]?.flags
                    .contains(.sharedTestTarget) == true
            }
            .map(\.name)

        if targetNames.isEmpty {
            return []
        }

        let clock = SuspendingClock()
        let start = clock.now

        var changedFiles = try gitFiles(.changed)
        var deletedFiles = try gitFiles(.onlyDeleted)

        if environment.impactAnalysisSymlinksSupportEnabled {
            var changedFilesLinks: Set<String> = []
            for file in changedFiles {
                changedFilesLinks.formUnion(getAllLink(to: file))
            }
            changedFiles.formUnion(changedFilesLinks)
            
            var deletedFilesLinks: Set<String> = []
            for file in deletedFiles {
                deletedFilesLinks.formUnion(getAllLink(to: file))
            }
            deletedFiles.formUnion(deletedFilesLinks)
        }
        
        let affectedGekoFiles = affectedGekoFiles(changedFiles: changedFiles, deletedFiles: deletedFiles)
        let initiallyChangedTargets: Set<ImpactGraphDependency>
        
        if !affectedGekoFiles.isEmpty {
            initiallyChangedTargets = allTargets(workspace: workspace)
            
            logger.info("Geko manifests have been affected, so all targets will be affected.")
            logger.info("Affected Geko manifests: \(affectedGekoFiles)")
        } else {
            let changedLocalTargets = try changedLocalTargets(
                workspace: workspace,
                sideTable: sideTable,
                changedFiles: changedFiles,
                deletedFiles: deletedFiles
            )
            let markedTargets = try markedAsChangedTargets(workspace: &workspace)
            let (originalLockfile, newLockfile) = try lockfiles()
            let lockfileChanges = try lockfileChanges(
                workspace: &workspace,
                externalDependenciesGraph: externalDependenciesGraph,
                originalLockfile: originalLockfile,
                newLockfile: newLockfile
            )
            initiallyChangedTargets = changedLocalTargets
                .union(lockfileChanges)
                .union(markedTargets)
            logger.info("Initially affected targets: \(initiallyChangedTargets)")

            logDump("Changed targets from source:\n", changedLocalTargets.map(\.description))
            logDump("Changed targets from lockfile:\n", lockfileChanges.map(\.description))
        }

        let allChangedTargets = allAffectedTargets(
            workspace: &workspace,
            externalDependencies: externalDependenciesGraph,
            changedTargets: initiallyChangedTargets
        )
        logger.info("All affected targets: \(allChangedTargets)")

        logDump("All changed targets", allChangedTargets.map(\.description))

        let time = clock.now - start
        logger.info("Time took to apply impact analysis to graph: \(time)")

        applyChanges(
            to: &workspace,
            sideTable: &sideTable,
            affectedTargets: Set(allChangedTargets),
            projectPath: projectPath,
            targetNames: targetNames
        )

        return []
    }
}

// MARK: - Private methods

extension ImpactAnalysisWorkspaceMapper {
    // MARK: - Utils

    private var sourceRef: String {
        environment.impactSourceRef ?? "HEAD"
    }

    private var targetRef: String {
        guard let ref = environment.impactTargetRef else {
            fatalError("Environment variable \(Constants.EnvironmentVariables.impactAnalysisTargetRef) should be set")
        }
        return ref
    }

    private func logDump(_ header: String, _ object: some Any) {
        var string = "\(header)\n"
        dump(object, to: &string)
        logger.debug("\(string)")
    }

    // MARK: - Sources diff calculation
    
    private enum GitFilesOption {
        case onlyDeleted
        case changed
        
        var filter: String {
            switch self {
            case .onlyDeleted:
                "D"
            case .changed:
                "d"
            }
        }
    }

    private func gitFiles(_ option: GitFilesOption) throws -> Set<String> {
        let diff: String
        if environment.impactAnalysisDebug {
            diff = try system.capture(["git", "diff", "--name-only", "--no-renames", "--diff-filter=\(option.filter)"]).chomp()
        } else {
            diff = try system.capture(["git", "diff", "\(targetRef)...\(sourceRef)", "--name-only", "--no-renames", "--diff-filter=\(option.filter)"]).chomp()
        }
        
        if diff.isEmpty {
            return Set()
        }
        
        return Set(diff.components(separatedBy: "\n"))
    }

    private func markedAsChangedTargets(
        workspace: inout WorkspaceWithProjects
    ) throws -> Set<ImpactGraphDependency> {
        let markedTargetNames = Set(environment.impactAnalysisChangedTargets)
        let markedProductNames = Set(environment.impactAnalysisChangedProducts)

        var result = Set<ImpactGraphDependency>()

        guard !markedTargetNames.isEmpty || !markedProductNames.isEmpty else {
            return result
        }

        for project in workspace.projects {
            for target in project.targets {
                if markedTargetNames.contains(target.name) {
                    let changedTarget = ImpactGraphDependency.target(name: target.name, path: project.path)
                    result.insert(changedTarget)

                    continue
                }

                if markedProductNames.contains(target.productName) {
                    let changedTarget = ImpactGraphDependency.target(name: target.name, path: project.path)
                    result.insert(changedTarget)

                    continue
                }
            }
        }

        return result
    }

    private func changedLocalTargets(
        workspace: borrowing WorkspaceWithProjects,
        sideTable: borrowing WorkspaceSideTable,
        changedFiles: Set<String>,
        deletedFiles: borrowing Set<String>
    ) throws -> Set<ImpactGraphDependency> {
        var result = Set<ImpactGraphDependency>()

        let rootPath = workspace.workspace.path
        let changedFilesAbsolutePaths = try changedFiles.map {
            let relativePath = try RelativePath(validating: $0)
            return rootPath.appending(relativePath)
        }

        for project in workspace.projects {
            if isAffectedProjectManifest(changedFiles: changedFiles, deletedFiles: deletedFiles, project: project, rootPath: rootPath) {
                for target in project.targets {
                    let changedTarget = ImpactGraphDependency.target(name: target.name, path: project.path)
                    result.insert(changedTarget)
                }
                continue
            }

            targetLoop: for target in project.targets {
                for sourceFiles in target.sources {
                    for source in sourceFiles.paths {
                        let relativePath = try fileHandler.resolveSymlinks(source).relative(to: rootPath).pathString

                        if changedFiles.contains(relativePath) {
                            let changedTarget = ImpactGraphDependency.target(name: target.name, path: project.path)
                            result.insert(changedTarget)

                            continue targetLoop
                        }
                    }
                }

                for resource in target.resources {
                    switch resource {
                    case let .glob(path, _, _, _):
                        fatalError("globs in resources must be unwrapped before applying impact analysis: \(path)")
                    case let .file(path, _, _), let .folderReference(path, _, _):
                        let relativePath = try fileHandler.resolveSymlinks(path)
                            .relative(to: rootPath).pathString
                        
                        for changedFile in changedFiles {
                            if changedFile.hasPrefix(relativePath) {
                                let changedTarget = ImpactGraphDependency.target(name: target.name, path: project.path)
                                result.insert(changedTarget)

                                continue targetLoop
                            }
                        }
                    }
                }

                for file in target.additionalFiles {
                    switch file {
                    case let .glob(path):
                        fatalError("globs in resources must be unwrapped before applying impact analysis: \(path)")
                    case let .file(path), let .folderReference(path):
                        let relativePath = try fileHandler.resolveSymlinks(path)
                            .relative(to: rootPath).pathString

                        if changedFiles.contains(relativePath) {
                            let changedTarget = ImpactGraphDependency.target(name: target.name, path: project.path)
                            result.insert(changedTarget)

                            continue targetLoop
                        }
                    }
                }

                for buildableFolder in target.buildableFolders {
                    for changedFile in changedFilesAbsolutePaths {
                        if buildableFolder.path.isAncestor(of: changedFile)
                            && !buildableFolder.exceptions.contains(changedFile)
                        {
                            let changedTarget = ImpactGraphDependency.target(name: target.name, path: project.path)
                            result.insert(changedTarget)

                            continue targetLoop
                        }
                    }
                }
                
                guard !deletedFiles.isEmpty else {
                    continue targetLoop
                }
                
                if isAnyDeletedFileInTarget(sources: sideTable.sources(path: project.path, name: target.name), deletedFiles: deletedFiles, rootPath: rootPath) ||
                    isAnyDeletedFileInTarget(resources: sideTable.resources(path: project.path, name: target.name), deletedFiles: deletedFiles, rootPath: rootPath) ||
                    isAnyDeletedFileInTarget(additionalFiles: sideTable.additionalFiles(path: project.path, name: target.name), deletedFiles: deletedFiles, rootPath: rootPath) ||
                    isAnyDeletedFileInTarget(buildableFolders: target.buildableFolders, deletedFiles: deletedFiles, rootPath: rootPath)
                {
                    let changedTarget = ImpactGraphDependency.target(name: target.name, path: project.path)
                    result.insert(changedTarget)
                    
                    continue targetLoop
                }
            }
        }

        return result
    }
    
    // MARK: - Private

    private func getAllLink(to pathString: String) -> [String] {
        var output: [String] = []
        for (link, target) in symlinks {
            if pathString.contains(target + "/") || pathString == target {      
                output.append(pathString.replacing(target, with: link))
            }
        }
        return output
    }

    
    private func isAffectedProjectManifest(
        changedFiles: Set<String>,
        deletedFiles: Set<String>,
        project: Project,
        rootPath: AbsolutePath
    ) -> Bool {
        if let podspecPath = project.podspecPath {
            let podspecPath = podspecPath.relative(to: rootPath).pathString
            return changedFiles.contains(podspecPath)
        }
        
        let projectPath = project.path
            .relative(to: rootPath)
            .pathString
        
        let pattern: String
        if projectPath == "." {
            pattern = #"^Project(\+[A-Za-z0-9_]+)?\.swift$"#
        } else {
            pattern = "^\(projectPath)/" + #"Project(\+[A-Za-z0-9_]+)?\.swift$"#
        }
        
        guard let projectAndExtensionsRegex = try? NSRegularExpression(pattern: pattern) else {
            logger.warning("Error creating regex for pattern: \(pattern)")
            return false
        }
        
        let affectedProjectFiles = changedFiles.union(deletedFiles).filter {
            isMatch(string: $0, regex: projectAndExtensionsRegex)
        }
        return !affectedProjectFiles.isEmpty
    }
    
    private func affectedGekoFiles(
        changedFiles: Set<String>,
        deletedFiles: Set<String>
    ) -> Set<String> {
        let excludedFiles: Set<String> = [
            "Geko/Dependencies/Cocoapods.lock",
            "Geko/Dependencies.swift",
        ]
        
        let changedAndDeletedFiles = changedFiles.union(deletedFiles).subtracting(excludedFiles)

        let gekoWorkspaceFiles = changedAndDeletedFiles.filter { file in
            isMatch(string: file, regex: .workspaceRegex)
        }
        
        let gekoFolderFiles = changedAndDeletedFiles
            .filter({ $0.hasPrefix("Geko/") })
        
        return gekoFolderFiles.union(gekoWorkspaceFiles)
    }
    
    private func allTargets(workspace: borrowing WorkspaceWithProjects) -> Set<ImpactGraphDependency> {
        var allTargets: Set<ImpactGraphDependency> = []
        
        for project in workspace.projects {
            for target in project.targets {
                let target = ImpactGraphDependency.target(name: target.name, path: project.path)
                allTargets.insert(target)
            }
        }
        
        return allTargets
    }
    
    private func isAnyDeletedFileInTarget(
        sources: [SourceFiles],
        deletedFiles: Set<String>,
        rootPath: AbsolutePath
    ) -> Bool {
        for source in sources {
            var matchedFiles: Set<String> = []
            
            for sourceFileGlob in source.paths {
                let pattern = globConverter.toRegex(glob: sourceFileGlob.relative(to: rootPath).pathString, extended: true, globstar: true)
                
                let matchedSources = deletedFiles.filter { deletedFile in
                    isMatch(path: deletedFile, pattern: pattern)
                }
                
                matchedFiles.formUnion(matchedSources)
            }
            
            for exclude in source.excluding {
                let regexStr = globConverter.toRegex(
                    glob: exclude.relative(to: rootPath).pathString,
                    extended: true,
                    globstar: true
                )
                
                let matchedExcluded = matchedFiles.filter {
                    isMatch(path: $0, pattern: regexStr)
                }
                
                matchedFiles.subtract(matchedExcluded)
             }
            
            if !matchedFiles.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func isAnyDeletedFileInTarget(
        resources: [FilePath],
        deletedFiles: Set<String>,
        rootPath: AbsolutePath
    ) -> Bool {
        for resource in resources {
            let pattern = globConverter.toRegex(glob: resource.relative(to: rootPath).pathString, extended: true, globstar: true, flags: "g")
            
            let matchedFiles = deletedFiles.filter { deletedFile in
                isMatch(path: deletedFile, pattern: pattern)
            }
            
            if !matchedFiles.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func isAnyDeletedFileInTarget(
        additionalFiles: [FilePath],
        deletedFiles: Set<String>,
        rootPath: AbsolutePath
    ) -> Bool {
        for additionalFile in additionalFiles {
            let pattern = globConverter.toRegex(glob: additionalFile.relative(to: rootPath).pathString, extended: true, globstar: true)
            
            let matchedFiles = deletedFiles.filter { deletedFile in
                isMatch(path: deletedFile, pattern: pattern)
            }
            
            if !matchedFiles.isEmpty {
                return true
            }
        }
        return false
    }
    
    private func isAnyDeletedFileInTarget(
        buildableFolders: [BuildableFolder],
        deletedFiles: Set<String>,
        rootPath: AbsolutePath
    ) -> Bool {
        guard let deletedFilesAbsolutePaths = try? deletedFiles.map({
            let relativePath = try RelativePath(validating: $0)
            return rootPath.appending(relativePath)
        }) else { return false }
        
        for buildableFolder in buildableFolders {
            for deletedFile in deletedFilesAbsolutePaths {
                if buildableFolder.path.isAncestor(of: deletedFile)
                    && !buildableFolder.exceptions.contains(deletedFile)
                {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func isMatch(path: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        return isMatch(string: path, regex: regex)
    }
    
    private func isMatch(string: String, regex: NSRegularExpression) -> Bool {
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, range: range) != nil
    }

    // MARK: - Lockfiles diff calculation

    private func lockfiles() throws -> (original: CocoapodsLockfile?, new: CocoapodsLockfile?) {
        let originalLockfile: Data?
        let originalLockfileContext: ParseYamlContext
        let newLockfile: Data?
        let newLockfileContext: ParseYamlContext

        let lockfilePath = try RelativePath(validating: "Geko/Dependencies/Cocoapods.lock")
        if environment.impactAnalysisDebug {
            let rootDir = fileHandler.currentPath

            originalLockfile = try? system.capture(["git", "show", "HEAD:\(lockfilePath.pathString)"]).chomp()
                .data(using: .utf8)
            originalLockfileContext = .git(path: lockfilePath, ref: "HEAD")

            let newLockfilePath = rootDir.appending(lockfilePath)
            newLockfile = try? fileHandler.readFile(newLockfilePath)
            newLockfileContext = .file(path: newLockfilePath)
        } else {
            originalLockfile = try? system.capture(["git", "show", "\(targetRef):\(lockfilePath.pathString)"]).chomp()
                .data(using: .utf8)
            originalLockfileContext = .git(path: lockfilePath, ref: "HEAD")

            newLockfile = try? system.capture(["git", "show", "\(sourceRef):\(lockfilePath.pathString)"]).chomp()
                .data(using: .utf8)
            newLockfileContext = .git(path: lockfilePath, ref: "HEAD")
        }

        var originalLockfileYml: CocoapodsLockfile?
        var newLockfileYml: CocoapodsLockfile?

        if let originalLockfile {
            originalLockfileYml = try CocoapodsLockfile.from(data: originalLockfile, context: originalLockfileContext)
        }

        if let newLockfile {
            newLockfileYml = try CocoapodsLockfile.from(data: newLockfile, context: newLockfileContext)
        }

        return (originalLockfileYml, newLockfileYml)
    }

    private func lockfileChanges(
        workspace: inout WorkspaceWithProjects,
        externalDependenciesGraph: DependenciesGraph,
        originalLockfile: CocoapodsLockfile?,
        newLockfile: CocoapodsLockfile?
    ) throws -> Set<ImpactGraphDependency> {
        guard
            let originalLockfile = originalLockfile,
            let newLockfile = newLockfile
        else {
            return []
        }

        var changedDependencies = Set<String>()

        func compare(_ origLockfile: CocoapodsLockfile, _ newLockfile: CocoapodsLockfile) {
            for (source, origSourceData) in origLockfile.podsBySource {
                guard let newSourceData = newLockfile.podsBySource[source] else {
                    changedDependencies.formUnion(origSourceData.pods.keys)
                    continue
                }

                if origSourceData.ref != newSourceData.ref {
                    changedDependencies.formUnion(origSourceData.pods.keys)
                    changedDependencies.formUnion(newSourceData.pods.keys)
                    continue
                }

                for (pod, oldPodData) in origSourceData.pods {
                    let newPodData = newSourceData.pods[pod]

                    if oldPodData != newPodData {
                        changedDependencies.insert(pod)
                    }
                }
            }
        }

        compare(originalLockfile, newLockfile)
        compare(newLockfile, originalLockfile)

        var result = Set<ImpactGraphDependency>()

        for dependency in changedDependencies {
            guard let dependencies = externalDependenciesGraph.externalDependencies[dependency] else {
                continue  // dependency was deleted
            }

            result.insert(.external(name: dependency))

            for dep in dependencies {
                switch dep {
                case let .bundle(path, _):
                    result.insert(.bundle(path: path))
                case let .framework(path, _, _):
                    result.insert(.framework(path: path))
                case let .library(path, _, _, _):
                    result.insert(.library(path: path))
                case let .project(target, path, _, _):
                    result.insert(.target(name: target, path: path))
                case let .xcframework(path, _, _):
                    result.insert(.xcframework(path: path))
                case .local, .sdk, .target, .xctest, .external:
                    break  // not applicable
                }
            }
        }

        return result
    }

    // MARK: - Impact analysis

    private func allAffectedTargets(
        workspace: inout WorkspaceWithProjects,
        externalDependencies: DependenciesGraph,
        changedTargets: Set<ImpactGraphDependency>
    ) -> [ImpactGraphDependency] {
        let dependencies = dependencies(
            workspace: &workspace,
            externalDependencies: externalDependencies
        )

        var cachedResult: [ImpactGraphDependency: Bool] = [:]
        for changedTarget in changedTargets {
            cachedResult[changedTarget] = true
        }

        func dfs(_ dependency: ImpactGraphDependency) -> Bool {
            if let result = cachedResult[dependency] {
                return result
            }

            guard let children = dependencies[dependency] else {
                cachedResult[dependency] = false
                return false
            }

            if children.intersection(changedTargets).count > 0 {
                cachedResult[dependency] = true
                return true
            }

            var res = false
            for child in children {
                res = res || dfs(child)
            }
            cachedResult[dependency] = res
            return res
        }

        for dependency in dependencies.keys {
            _ = dfs(dependency)
        }

        return cachedResult.filter(\.value).map(\.key)
    }

    // MARK: Graph manipulation

    private func applyChanges(
        to workspace: inout WorkspaceWithProjects,
        sideTable: inout WorkspaceSideTable,
        affectedTargets: consuming Set<ImpactGraphDependency>,
        projectPath: AbsolutePath,
        targetNames: [String]
    ) {
        for p in 0 ..< workspace.projects.count {
            guard workspace.projects[p].path == projectPath else { continue }

            let project = workspace.projects[p]

            for t in 0 ..< workspace.projects[p].targets.count {
                var target = workspace.projects[p].targets[t]

                guard targetNames.contains(target.name) else { continue }

                logDump("dependencies of \(target.name) before\n", target.dependencies.map { $0.description })

                workspace.projects[p].targets[t].dependencies = target.dependencies.filter { targetDependency in
                    guard let member = map(targetDependency: targetDependency, projectPath: project.path) else {
                        return true
                    }

                    guard
                        !affectedTargets.contains(member),
                        case let .target(name, path) = member,
                        let flags = sideTable.projects[path]?.targets[name]?.flags,
                        flags.contains(.sharedTestTargetGeneratedFramework)
                    else {
                        return true
                    }

                    if let projectIdx = workspace.projects.firstIndex(where: { $0.path == path }) {
                        if let targetIdx = workspace.projects[projectIdx].targets.firstIndex(where: { $0.name == name }) {
                            workspace.projects[projectIdx].targets[targetIdx].prune = true
                        }
                    }
                    return false
                }

                target = workspace.projects[p].targets[t]
                logDump("dependencies of \(target.name) after\n", target.dependencies.map { $0.description })
            }
        }
    }

    private func dependencies(
        workspace: inout WorkspaceWithProjects,
        externalDependencies: DependenciesGraph
    ) -> [ImpactGraphDependency: Set<ImpactGraphDependency>] {
        var result: [ImpactGraphDependency: Set<ImpactGraphDependency>] = [:]

        workspace.projects.forEach { project in
            project.targets.forEach { target in
                let impactGraphDependency = ImpactGraphDependency.target(name: target.name, path: project.path)
                let targetDependencies = target.dependencies.compactMap { targetDependency in
                    map(targetDependency: targetDependency, projectPath: project.path)
                }
                result[impactGraphDependency] = Set(targetDependencies)
            }
        }

        for (name, dependencies) in externalDependencies.externalDependencies {
            let nodeDependencies = dependencies.compactMap {
                map(targetDependency: $0, projectPath: nil)
            }
            result[.external(name: name)] = Set(nodeDependencies)

            for dependency in dependencies {
                switch dependency {
                case let .project(target, path, _, _):
                    guard let project = externalDependencies.externalProjects[path] else {
                        logger.warning("[ImpactAnalysis] Cannot find external project with path \(path)")
                        continue
                    }

                    guard let targetIdx = project.targets.firstIndex(where: { $0.name == target }) else {
                        logger.warning("[ImpactAnalysis] Cannot find target \(target) in external project with path \(path)")
                        continue
                    }

                    let impactGraphDependency = ImpactGraphDependency.target(name: target, path: path)
                    let targetDependencies = project.targets[targetIdx].dependencies.compactMap { targetDependency in
                        map(targetDependency: targetDependency, projectPath: project.path)
                    }
                    result[impactGraphDependency] = Set(targetDependencies)

                case let .framework(path, _, _),
                    let .library(path, _, _, _),
                    let .xcframework(path, _, _):
                    guard let impactGraphDependency = map(targetDependency: dependency, projectPath: nil) else {
                        continue
                    }

                    let nodeDependencies = externalDependencies.externalFrameworkDependencies[path]?.compactMap {
                        map(targetDependency: $0, projectPath: nil)
                    } ?? []
                    result[impactGraphDependency] = Set(nodeDependencies)

                case .target, .local, .sdk, .bundle, .xctest, .external:
                    break
                }
            }
        }

        return result
    }

    private func map(targetDependency: TargetDependency, projectPath: AbsolutePath?) -> ImpactGraphDependency? {
        switch targetDependency {
        case let .project(name, path, _, _):
            return ImpactGraphDependency.target(name: name, path: path)
        case let .target(name, _, _):
            // Target outside of project is possible only for external dependencies,
            // but that state will throw error when loading external graph
            // at the start of geko.
            guard let projectPath else { return nil }
            return ImpactGraphDependency.target(name: name, path: projectPath)
        case let .local(name, _, _):
            logger.warning("[ImpactAnalysis] Unresolved local dependency '\(name)' when building graph")
            return nil
        case let .bundle(path: path, _):
            return .bundle(path: path)
        case let .framework(path, _, _):
            return .framework(path: path)
        case let .library(path, _, _, _):
            return .library(path: path)
        case let .xcframework(path, _, _):
            return .xcframework(path: path)
        case let .external(name, _):
            return .external(name: name)
        case .sdk, .xctest:
            return nil
        }
    }
}
