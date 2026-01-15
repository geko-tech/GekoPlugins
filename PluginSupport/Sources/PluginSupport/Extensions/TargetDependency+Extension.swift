import ProjectDescription

extension TargetDependency: CustomStringConvertible {
    public var description: String {
        switch self {
        case .target:
            "target '\(name)'"
        case .local:
            "local '\(name)'"
        case .project:
            "project '\(name)'"
        case .framework:
            "framework '\(name)'"
        case .library:
            "library '\(name)'"
        case .sdk:
            "sdk '\(name)'"
        case .xcframework:
            "xcframework '\(name)'"
        case .bundle:
            "bundle '\(name)'"
        case .xctest:
            "xctest '\(name)'"
        case .external:
            "external '\(name)'"
        }
    }

    var name: String {
        switch self {
        case let .target(name, _, _):
            return name
        case let .local(name, _, _):
            return name
        case let .project(target, _, _, _):
            return target
        case let .framework(path, _, _):
            return path.basename
        case let .xcframework(path, _, _):
            return path.basename
        case let .library(path, _, _, _):
            return path.basename
        case let .sdk(name, _, _, _):
            return name
        case let .bundle(path, _):
            return path.basename
        case .xctest:
            return "xctest"
        case .external:
            fatalError("External should be unwrapped during manifest mapping")
        }
    }
}
