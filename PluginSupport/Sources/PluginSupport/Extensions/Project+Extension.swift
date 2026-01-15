import ProjectDescription

public typealias IDETemplateMacros = ProjectDescription.FileHeaderTemplate

extension Project {
    /// Initializes the project with its attributes.
    ///
    /// - Parameters:
    ///   - path: Path to the folder that contains the project manifest.
    ///   - sourceRootPath: Path to the directory where the Xcode project will be generated.
    ///   - xcodeProjPath: Path to the Xcode project that will be generated.
    ///   - name: Project name.
    ///   - organizationName: Organization name.
    ///   - defaultKnownRegions: Default known regions.
    ///   - developmentRegion: Development region.
    ///   - options: Additional project options.
    ///   - settings: The settings to apply at the project level
    ///   - filesGroup: The root group to place project files within
    ///   - targets: The project targets
    ///                      *(Those won't be included in any build phases)*
    ///   - packages: Project swift packages.
    ///   - schemes: Project schemes.
    ///   - ideTemplateMacros: IDE template macros that represent content of IDETemplateMacros.plist.
    ///   - additionalFiles: The additional files to include in the project
    ///   - resourceSynthesizers: `ResourceSynthesizers` that will be applied on individual target's resources
    ///   - lastUpgradeCheck: The version in which a check happened related to recommended settings after updating Xcode.
    ///   - isExternal: Indicates whether the project is imported through `Dependencies.swift`.
    public init(
        path: AbsolutePath,
        sourceRootPath: AbsolutePath,
        xcodeProjPath: AbsolutePath,
        name: String,
        organizationName: String?,
        options: Options,
        settings: Settings,
        filesGroup: ProjectGroup,
        targets: [Target],
        schemes: [Scheme],
        ideTemplateMacros: IDETemplateMacros?,
        additionalFiles: [FileElement],
        lastUpgradeCheck: Version?,
        isExternal: Bool,
        podspecPath: AbsolutePath? = nil
    ) {
        self.init(
            name: name,
            organizationName: organizationName,
            options: options,
            settings: settings,
            targets: targets,
            schemes: schemes,
            fileHeaderTemplate: ideTemplateMacros,
            additionalFiles: additionalFiles
        )

        self.path = path
        self.sourceRootPath = sourceRootPath
        self.xcodeProjPath = xcodeProjPath
        self.podspecPath = podspecPath
        self.lastUpgradeCheck = lastUpgradeCheck
        self.isExternal = isExternal
        self.filesGroup = filesGroup
    }
    
    /// Returns a copy of the project with the given targets set.
    /// - Parameter targets: Targets to be set to the copy.
    public func with(targets: [Target]) -> Project {
        Project(
            path: path,
            sourceRootPath: sourceRootPath,
            xcodeProjPath: xcodeProjPath,
            name: name,
            organizationName: organizationName,
            options: options,
            settings: settings,
            filesGroup: filesGroup,
            targets: targets,
            schemes: schemes,
            ideTemplateMacros: fileHeaderTemplate,
            additionalFiles: additionalFiles,
            lastUpgradeCheck: lastUpgradeCheck,
            isExternal: isExternal,
            podspecPath: podspecPath
        )
    }

    /// Returns a copy of the project with the given schemes set.
    /// - Parameter schemes: Schemes to be set to the copy.
    public func with(schemes: [Scheme]) -> Project {
        Project(
            path: path,
            sourceRootPath: sourceRootPath,
            xcodeProjPath: xcodeProjPath,
            name: name,
            organizationName: organizationName,
            options: options,
            settings: settings,
            filesGroup: filesGroup,
            targets: targets,
            schemes: schemes,
            ideTemplateMacros: fileHeaderTemplate,
            additionalFiles: additionalFiles,
            lastUpgradeCheck: lastUpgradeCheck,
            isExternal: isExternal,
            podspecPath: podspecPath
        )
    }
}
