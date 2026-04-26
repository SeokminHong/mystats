import Foundation
import Combine
import MystatsCore

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            save(settings)
        }
    }

    private let defaults: UserDefaults
    private let key = "mystats.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.load(from: defaults, key: key)
    }

    func setMenuBarItem(_ item: MenuBarItem, enabled: Bool) {
        if enabled {
            guard !settings.menuBarItems.contains(item) else {
                return
            }
            settings.menuBarItems.append(item)
        } else {
            settings.menuBarItems.removeAll { $0 == item }
        }
    }

    private func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func load(from defaults: UserDefaults, key: String) -> AppSettings {
        guard
            let data = defaults.data(forKey: key),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return settings
    }
}
