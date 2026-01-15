import ProjectDescription

extension Settings {

    public func with(base: SettingsDictionary, updateExcluded: Bool = false) -> Settings {
        var newDefaults = defaultSettings
        if updateExcluded {
            switch defaultSettings {
            case let .recommended(excluding):
                newDefaults = .recommended(excluding: excluding.union(base.keys))
            case let .essential(excluding):
                newDefaults = .essential(excluding: excluding.union(base.keys))
            case .none:
                break
            }
        }

        return .init(
            base: base,
            configurations: configurations,
            defaultSettings: newDefaults
        )
    }
}
