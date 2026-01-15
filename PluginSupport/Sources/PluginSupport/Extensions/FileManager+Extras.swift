import Foundation

private extension String {
    func appendingPathComponent(_ component: String) -> String {
        if self.last == "/" {
            return "\(self)\(component)"
        } else {
            return "\(self)/\(component)"
        }
    }
}

extension FileManager {
    func subdirectoriesResolvingSymbolicLinks(atPath path: String) -> [String] {
        var result: [String] = []
        subdirectoriesResolvingSymbolicLinks(atNestedPath: nil, basePath: path, result: &result)
        return result
    }

    private func subdirectoriesResolvingSymbolicLinks(atNestedPath nestedPath: String?, basePath: String, result: inout [String]) {
        let currentLevelPath = nestedPath.map { basePath.appendingPathComponent($0) } ?? basePath
        let resolvedCurrentLevelPath = resolvingSymbolicLinks(path: currentLevelPath)

        guard let resolvedSubpathsFromCurrentRoot = try? subpathsOfDirectory(atPath: resolvedCurrentLevelPath) else {
            return
        }

        for subpath in resolvedSubpathsFromCurrentRoot {
            let relativeSubpath = nestedPath.map { $0.appendingPathComponent(subpath) } ?? subpath
            let completeSubpath = basePath.appendingPathComponent(relativeSubpath)

            if isSymbolicLinkToDirectory(path: completeSubpath) {
                result.append(relativeSubpath)
                subdirectoriesResolvingSymbolicLinks(atNestedPath: relativeSubpath, basePath: basePath, result: &result)
            } else if isDirectory(path: completeSubpath) {
                result.append(relativeSubpath)
            }
        }
    }

    private func isSymbolicLinkToDirectory(path: String) -> Bool {
        let pathResolvingSymbolicLinks = resolvingSymbolicLinks(path: path)
        return pathResolvingSymbolicLinks != path && isDirectory(path: pathResolvingSymbolicLinks)
    }

    private func resolvingSymbolicLinks(path: String) -> String {
        guard let destination = try? destinationOfSymbolicLink(atPath: path) else {
            return path
        }

        let absoluteDestination: String
        if destination.starts(with: "/") {
            absoluteDestination = destination
        } else {
            // Transform symlinks with relative destinations to absolute paths.
            absoluteDestination = URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent(destination).path
        }

        return resolvingSymbolicLinks(path: absoluteDestination)
    }

    func isDirectory(path: String) -> Bool {
        #if os(macOS)
            var isDirectoryBool = ObjCBool(false)
        #else
            var isDirectoryBool = false
        #endif
        let doesFileExist = fileExists(atPath: path, isDirectory: &isDirectoryBool)
        #if os(macOS)
            return doesFileExist && isDirectoryBool.boolValue
        #else
            return doesFileExist && isDirectoryBool
        #endif
    }
}
