import ProjectDescription

extension FileElement {
    public var path: AbsolutePath {
        switch self {
        case let .glob(path):
            return path
        case let .file(path):
            return path
        case let .folderReference(path):
            return path
        }
    }
}