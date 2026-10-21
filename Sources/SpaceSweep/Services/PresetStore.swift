import Foundation

struct PresetStore {
    private let defaults: UserDefaults
    private let key = "spacesweep.quickCleanRules.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [QuickCleanRule] {
        guard let data = defaults.data(forKey: key),
              let rules = try? JSONDecoder().decode([QuickCleanRule].self, from: data) else {
            return []
        }
        return rules
    }

    func save(_ rules: [QuickCleanRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

struct SettingsStore {
    private let defaults: UserDefaults
    private let scanKey = "spacesweep.scanSettings.v1"
    private let modeKey = "spacesweep.removalMode.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadScanSettings() -> ScanSettings {
        guard let data = defaults.data(forKey: scanKey),
              let settings = try? JSONDecoder().decode(ScanSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func saveScanSettings(_ settings: ScanSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: scanKey)
    }

    func loadRemovalMode() -> RemovalMode {
        guard let raw = defaults.string(forKey: modeKey),
              let mode = RemovalMode(rawValue: raw) else {
            return .trash
        }
        return mode
    }

    func saveRemovalMode(_ mode: RemovalMode) {
        defaults.set(mode.rawValue, forKey: modeKey)
    }
}
