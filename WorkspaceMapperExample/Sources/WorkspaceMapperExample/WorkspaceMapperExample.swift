import ProjectDescription
import ProjectDescriptionHelpers

public final class MyWorkspaceMapper {

    public init() {}

    public func map(workspace: inout WorkspaceWithProjects, params: [String: String], dependenciesGraph: DependenciesGraph) throws -> ([SideEffectDescriptor], [LintingIssue]) {
        for project in workspace.projects {
            print("project: \(project.name)")
            for target in project.targets {
                print("  - \(target.name)")
            }
        }
        return ([], [])
    }
}

@_cdecl("loadGekoPlugin")
public func loadGekoPlugin() -> UnsafeMutableRawPointer {
    let plugin = GekoPlugin { (workspace, params, dependenciesGraph) in
        let someStruct = try SomeStruct.fromJSONString(params[ProjectDescriptionHelpers.Constants.parameterName])
        print("someStruct:", someStruct)
        return try MyWorkspaceMapper().map(workspace: &workspace, params: params, dependenciesGraph: dependenciesGraph)
    }
    return plugin.toPointer()
}
