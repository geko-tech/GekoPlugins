import Foundation
import ProjectDescription
import ProjectDescriptionHelpers
import PluginSupport

@_cdecl("loadGekoPlugin")
public func loadGekoPlugin() -> UnsafeMutableRawPointer {
    PluginSupport.LogOutput.bootstrap()

    var sideTable = WorkspaceSideTable()
    let generateSharedTestTargetMapper = GenerateSharedTestTargetMapper()
    let impactAnalysisWorkspaceMapper = ImpactAnalysisWorkspaceMapper()
    let generateSharedTestTargetApphostFilesWorkspaceMapper = GenerateSharedTestTargetApphostFilesWorkspaceMapper()

    let plugin = GekoPlugin(
        workspaceMapperWithGlobs: { (workspace, params, dependenciesGraph) in
            workspace.projects.forEach { project in
                project.targets.forEach { target in 
                    let path = project.path
                    sideTable.setSources(target.sources, path: path, name: target.name)
                    sideTable.setResources(target.resources.map { $0.path }, path: path, name: target.name)
                    sideTable.setAdditionalFiles(target.additionalFiles.map { $0.path }, path: path, name: target.name)
                }
            }
            return ([], [])
        },
        workspaceMapper: { (workspace, params, dependenciesGraph) in
            let generateSharedTestTarget = try GenerateSharedTestTarget.fromJSONString(params[ProjectDescriptionHelpers.Constants.generateSharedTestTargetKey])
            
            var sideEffects: [SideEffectDescriptor] = []
            sideEffects.append(contentsOf: try generateSharedTestTargetMapper.map(workspace: &workspace, sideTable: &sideTable, gstt: generateSharedTestTarget))
            if Environment.shared.impactAnalysisEnabled {
                sideEffects.append(contentsOf: try impactAnalysisWorkspaceMapper.map(workspace: &workspace, sideTable: &sideTable, externalDependenciesGraph: dependenciesGraph, gstt: generateSharedTestTarget))
            }
            sideEffects.append(contentsOf: try generateSharedTestTargetApphostFilesWorkspaceMapper.map(workspace: &workspace, sideTable: &sideTable))
            return (sideEffects, [])
        }
    )
    return plugin.toPointer()
}

