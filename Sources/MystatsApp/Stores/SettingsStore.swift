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
        guard settings.menuBarItems.contains(item) != enabled else {
            return
        }

        guard enabled || settings.menuBarItems.count > 1 else {
            return
        }

        if enabled {
            settings.menuBarItems.append(item)
        } else {
            settings.menuBarItems.removeAll { $0 == item }
        }
    }

    func isMenuBarItemEnabled(_ item: MenuBarItem) -> Bool {
        settings.menuBarItems.contains(item)
    }

    func canDisableMenuBarItem(_ item: MenuBarItem) -> Bool {
        !settings.menuBarItems.contains(item) || settings.menuBarItems.count > 1
    }

    func metricItemSettings(for item: MenuBarItem) -> MetricItemSettings {
        settings.settings(for: item)
    }

    func updateMetricItemSettings(
        for item: MenuBarItem,
        _ update: (inout MetricItemSettings) -> Void
    ) {
        var next = settings.metricItemSettings[item] ?? .default
        update(&next)

        guard settings.metricItemSettings[item] != next else {
            return
        }

        settings.metricItemSettings[item] = next
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
