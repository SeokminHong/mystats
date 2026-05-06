import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var menuBarItems: [MenuBarItem]
    public var metricItemSettings: [MenuBarItem: MetricItemSettings]
    public var samplingMode: SamplingMode
    public var showUnknownSensors: Bool
    public var includeVPNInterfaces: Bool
    public var includeExternalDisks: Bool
    public var launchAtLogin: Bool
    public var temperatureUnit: TemperatureUnit
    public var chartTimeWindow: ChartTimeWindow

    public init(
        menuBarItems: [MenuBarItem] = Self.defaultMenuBarItems,
        metricItemSettings: [MenuBarItem: MetricItemSettings] = Self.defaultMetricItemSettings(),
        samplingMode: SamplingMode = .normal,
        showUnknownSensors: Bool = false,
        includeVPNInterfaces: Bool = false,
        includeExternalDisks: Bool = false,
        launchAtLogin: Bool = false,
        temperatureUnit: TemperatureUnit = .celsius,
        chartTimeWindow: ChartTimeWindow = .realtime
    ) {
        self.menuBarItems = Self.sanitizedMenuBarItems(menuBarItems)
        self.metricItemSettings = Self.sanitizedMetricItemSettings(metricItemSettings)
        self.samplingMode = samplingMode
        self.showUnknownSensors = showUnknownSensors
        self.includeVPNInterfaces = includeVPNInterfaces
        self.includeExternalDisks = includeExternalDisks
        self.launchAtLogin = launchAtLogin
        self.temperatureUnit = temperatureUnit
        self.chartTimeWindow = chartTimeWindow
    }

    public func settings(for item: MenuBarItem) -> MetricItemSettings {
        metricItemSettings[item] ?? .default
    }

    public static func defaultMetricItemSettings() -> [MenuBarItem: MetricItemSettings] {
        Dictionary(uniqueKeysWithValues: MenuBarItem.allCases.map { ($0, MetricItemSettings.default) })
    }

    public static let defaultMenuBarItems: [MenuBarItem] = [.cpu, .gpu, .network]

    private enum CodingKeys: String, CodingKey {
        case menuBarItems
        case metricItemSettings
        case samplingMode
        case showUnknownSensors
        case includeVPNInterfaces
        case includeExternalDisks
        case launchAtLogin
        case temperatureUnit
        case chartTimeWindow
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMenuBarItems = try Self.decodeMenuBarItems(from: container) ?? Self.defaultMenuBarItems
        self.menuBarItems = Self.sanitizedMenuBarItems(decodedMenuBarItems)
        self.metricItemSettings = try Self.decodeMetricItemSettings(from: container) ?? Self.defaultMetricItemSettings()
        self.samplingMode = try container.decodeIfPresent(SamplingMode.self, forKey: .samplingMode) ?? .normal
        self.showUnknownSensors = try container.decodeIfPresent(Bool.self, forKey: .showUnknownSensors) ?? false
        self.includeVPNInterfaces = try container.decodeIfPresent(Bool.self, forKey: .includeVPNInterfaces) ?? false
        self.includeExternalDisks = try container.decodeIfPresent(Bool.self, forKey: .includeExternalDisks) ?? false
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.temperatureUnit = try container.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit) ?? .celsius
        self.chartTimeWindow = try container.decodeIfPresent(ChartTimeWindow.self, forKey: .chartTimeWindow) ?? .realtime
    }

    private static func sanitizedMenuBarItems(_ items: [MenuBarItem]) -> [MenuBarItem] {
        var seen = Set<MenuBarItem>()
        let supported = items.filter { item in
            guard item.isUserVisible, !seen.contains(item) else {
                return false
            }
            seen.insert(item)
            return true
        }
        return supported.isEmpty ? defaultMenuBarItems : supported
    }

    private static func decodeMenuBarItems(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [MenuBarItem]? {
        guard let rawValues = try container.decodeIfPresent([String].self, forKey: .menuBarItems) else {
            return nil
        }
        return rawValues.compactMap(MenuBarItem.init(rawValue:))
    }

    private static func decodeMetricItemSettings(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> [MenuBarItem: MetricItemSettings]? {
        guard let rawSettings = try container.decodeIfPresent([String: MetricItemSettings].self, forKey: .metricItemSettings) else {
            return nil
        }

        return rawSettings.reduce(into: Self.defaultMetricItemSettings()) { result, entry in
            guard let item = MenuBarItem(rawValue: entry.key), item.isUserVisible else {
                return
            }
            result[item] = entry.value
        }
    }

    private static func sanitizedMetricItemSettings(
        _ settings: [MenuBarItem: MetricItemSettings]
    ) -> [MenuBarItem: MetricItemSettings] {
        settings.reduce(into: Self.defaultMetricItemSettings()) { result, entry in
            guard entry.key.isUserVisible else {
                return
            }
            result[entry.key] = entry.value
        }
    }
}

public struct MetricItemSettings: Codable, Equatable, Sendable {
    public var showsSecondaryValue: Bool
    public var showsMenuBarSparkline: Bool
    public var showsPopoverDetails: Bool

    public init(
        showsSecondaryValue: Bool = true,
        showsMenuBarSparkline: Bool = true,
        showsPopoverDetails: Bool = true
    ) {
        self.showsSecondaryValue = showsSecondaryValue
        self.showsMenuBarSparkline = showsMenuBarSparkline
        self.showsPopoverDetails = showsPopoverDetails
    }

    public static let `default` = MetricItemSettings()
}

public enum MenuBarItem: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case cpu
    case gpu
    /// Legacy persisted value. Temperature is displayed under CPU/GPU.
    case temperature
    case network
    case disk

    public static let allCases: [MenuBarItem] = [.cpu, .gpu, .network, .disk]

    public var id: String { rawValue }

    public var isUserVisible: Bool {
        self != .temperature
    }
}

public enum SamplingMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case low
    case normal
    case high

    public var id: String { rawValue }

    public func sampleInterval(isInteractive: Bool) -> TimeInterval {
        switch (self, isInteractive) {
        case (.low, false):
            return 15
        case (.low, true):
            return 5
        case (.normal, false):
            return 5
        case (.normal, true):
            return 1
        case (.high, false):
            return 2
        case (.high, true):
            return 1
        }
    }
}

public enum TemperatureUnit: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case celsius
    case fahrenheit

    public var id: String { rawValue }
}

public enum ChartTimeWindow: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case realtime
    case day
    case week

    public var id: String { rawValue }

    public var duration: TimeInterval {
        switch self {
        case .realtime:
            return 15 * 60
        case .day:
            return 24 * 60 * 60
        case .week:
            return 7 * 24 * 60 * 60
        }
    }

    public var summaryLabel: String {
        switch self {
        case .realtime:
            return "Last 15m"
        case .day:
            return "Last 24h"
        case .week:
            return "Last 7d"
        }
    }
}
