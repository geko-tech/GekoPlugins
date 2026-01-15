import ProjectDescription

enum ImpactGraphDependency: Hashable, CustomStringConvertible, Comparable, Codable {
    case target(name: String, path: AbsolutePath)
    case bundle(path: AbsolutePath)
    case framework(path: AbsolutePath)
    case library(path: AbsolutePath)
    case xcframework(path: AbsolutePath)
    case external(name: String)

    var description: String {
        switch self {
        case .target:
            "target '\(name)'"
        case .bundle:
            "bundle '\(name)'"
        case .framework:
            "framework '\(name)'"
        case .library:
            "library '\(name)'"
        case .xcframework:
            "xcframework '\(name)'"
        case .external:
            "external '\(name)'"
        }
    }

    var name: String {
        switch self {
        case let .target(name, _):
            name
        case let .bundle(path),
            let .framework(path),
            let .library(path),
            let .xcframework(path):
            path.basename
        case let .external(name):
            name
        }
    }
}
