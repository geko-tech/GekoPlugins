import Foundation
import ProjectDescription

public struct GenerateSharedTestTarget: WorkspaceMapperParameter, Equatable {
    public let installTo: String
    public let targets: [SharedTestTarget]

    public init(installTo: String, targets: [SharedTestTarget]) {
        self.installTo = installTo
        self.targets = targets
    }
}

/// Description for a shared test target
public struct SharedTestTarget: Codable, Equatable {
    public let testsPattern: String
    public let except: String?
    public let use: [String]
    public let name: String
    public let count: Int
    public let needAppHost: Bool

    public static func generate(name: String, testsPattern: String, except: String? = nil, needAppHost: Bool = false, count: Int = 1) -> SharedTestTarget {
        return SharedTestTarget(
            testsPattern: testsPattern,
            except: except,
            use: [],
            name: name,
            count: count,
            needAppHost: needAppHost
        )
    }

    public static func use(_ host: String, testsPattern: String, except: String? = nil) -> SharedTestTarget {
        return .use([host], testsPattern: testsPattern, except: except)
    }

    public static func use(_ hosts: [String], testsPattern: String, except: String? = nil) -> SharedTestTarget {
        return SharedTestTarget(
            testsPattern: testsPattern,
            except: except,
            use: hosts,
            name: "",
            count: 0,
            needAppHost: false
        )
    }
}
