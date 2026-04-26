import Foundation

@MainActor
final class AppRuntime {
    static let shared = AppRuntime()

    let metricStore = MetricStore()
    let settingsStore = SettingsStore()

    private init() {}
}

