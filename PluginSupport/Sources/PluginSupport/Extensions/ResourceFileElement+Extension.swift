import ProjectDescription

extension ResourceFileElement {
    public var path: AbsolutePath {
        switch self {
        case let .glob(pattern, _, _, _):
            return pattern
        case let .file(path, _, _):
            return path
        case let .folderReference(path, _, _):
            return path
        }
    }
}