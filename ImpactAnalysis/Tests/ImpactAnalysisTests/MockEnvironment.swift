import ImpactAnalysis

final class MockEnvironment: Environmenting {
    var impactAnalysisEnabled: Bool = false
    var impactSourceRef: String? = nil
    var impactTargetRef: String? = nil
    var impactAnalysisDebug: Bool = false
    var impactAnalysisChangedTargets: [String] = []
    var impactAnalysisChangedProducts: [String] = []
    var impactAnalysisSymlinksSupportEnabled: Bool = false
}
