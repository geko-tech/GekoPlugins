import Foundation

enum Constants {
    enum DerivedDirectory {
        public static let name = "Derived"
        public static let sources = "Sources"
    }

    enum EnvironmentVariables {
        public static let impactAnalysisEnabled = "GEKO_PLUGIN_IMPACT_ANALYSIS_ENABLED"
        public static let impactAnalysisSourceRef = "GEKO_IMPACT_SOURCE_REF"
        public static let impactAnalysisTargetRef = "GEKO_IMPACT_TARGET_REF"
        public static let impactAnalysisDebug = "GEKO_IMPACT_ANALYSIS_DEBUG"
        public static let impactAnalysisChangedTargets = "GEKO_IMPACT_ANALYSIS_CHANGED_TARGET_NAMES"
        public static let impactAnalysisChangedProducts = "GEKO_IMPACT_ANALYSIS_CHANGED_PRODUCT_NAMES"
        public static let impactAnalysisSymlinksSupportEnabled = "GEKO_IMPACT_ANALYSIS_SYMLINKS_SUPPORT_ENABLED"
    }
}
