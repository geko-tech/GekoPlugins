import Foundation
import ProjectDescription

public protocol Environmenting: AnyObject {
    /// Enabled impact analysis
    var impactAnalysisEnabled: Bool { get }

    /// Returns source ref for impact analysis
    var impactSourceRef: String? { get }

    /// Returns target ref for impact analysis
    var impactTargetRef: String? { get }

    /// Returns true if impact analysis should run in debug mode
    var impactAnalysisDebug: Bool { get }

    /// Returns list of targets marked as changed through env var
    var impactAnalysisChangedTargets: [String] { get }

    /// Returns list of targets whos product names marked as changed through env var
    var impactAnalysisChangedProducts: [String] { get }

    /// Enabled symlinks support
    var impactAnalysisSymlinksSupportEnabled: Bool { get }
}

/// Local environment controller.
public class Environment: Environmenting {
    public static var shared: Environmenting = Environment()

    public var impactAnalysisEnabled: Bool {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisEnabled] == "true"
    }

    public var impactSourceRef: String? {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisSourceRef]
    }

    public var impactTargetRef: String? {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisTargetRef]
    }

    public var impactAnalysisDebug: Bool {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisDebug] == "true"
    }

    public var impactAnalysisChangedTargets: [String] {
        return commaSeparatedList(from: Constants.EnvironmentVariables.impactAnalysisChangedTargets)
    }

    public var impactAnalysisChangedProducts: [String] {
        return commaSeparatedList(from: Constants.EnvironmentVariables.impactAnalysisChangedProducts)
    }

    public var impactAnalysisSymlinksSupportEnabled: Bool {
        ProcessInfo.processInfo.environment[Constants.EnvironmentVariables.impactAnalysisSymlinksSupportEnabled] == "true"
    }

    // MARK: - Private

    private func commaSeparatedList(from envVar: String) -> [String] {
        guard let envVar = ProcessInfo.processInfo.environment[envVar] else {
            return []
        }

        return envVar.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}