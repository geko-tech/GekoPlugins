import Foundation
import ProjectDescription

extension CocoapodsLockfile {
    public static func from(data: Data, context: ParseYamlContext) throws -> CocoapodsLockfile? {
        let lockfile: Lockfile = try parseYaml(data, context: context)
        
        return .init(podsBySource: lockfile)
    }
}
