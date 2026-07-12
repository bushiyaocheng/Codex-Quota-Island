import Foundation

enum ExpansionMode: String {
    case click
    case hover
}

enum ExpansionPreference {
    static let storageKey = "islandExpansionMode"
    private static let legacyClickStorageKey = "clickExpansionEnabled"
    private static let legacyHoverStorageKey = "hoverExpansionEnabled"

    static var mode: ExpansionMode {
        mode(in: .standard)
    }

    static func mode(in defaults: UserDefaults) -> ExpansionMode {
        if let rawValue = defaults.string(forKey: storageKey),
           let mode = ExpansionMode(rawValue: rawValue) {
            return mode
        }

        if defaults.bool(forKey: legacyClickStorageKey),
           !defaults.bool(forKey: legacyHoverStorageKey) {
            return .click
        }
        return .hover
    }

    static func select(_ mode: ExpansionMode, in defaults: UserDefaults = .standard) {
        guard self.mode(in: defaults) != mode else { return }
        setMode(mode, in: defaults)
    }

    private static func setMode(_ mode: ExpansionMode, in defaults: UserDefaults) {
        defaults.set(mode.rawValue, forKey: storageKey)
        defaults.set(mode == .click, forKey: legacyClickStorageKey)
        defaults.set(mode == .hover, forKey: legacyHoverStorageKey)
    }
}
