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
        menuBarItems: [MenuBarItem] = [.cpu, .gpu, .temperature, .network],
        metricItemSettings: [MenuBarItem: MetricItemSettings] = Self.defaultMetricItemSettings(),
        samplingMode: SamplingMode = .normal,
        showUnknownSensors: Bool = false,
        includeVPNInterfaces: Bool = false,
        includeExternalDisks: Bool = false,
        launchAtLogin: Bool = false,
        temperatureUnit: TemperatureUnit = .celsius,
        chartTimeWindow: ChartTimeWindow = .realtime
    ) {
        self.menuBarItems = menuBarItems
        self.metricItemSettings = metricItemSettings
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
        self.menuBarItems = try container.decodeIfPresent([MenuBarItem].self, forKey: .menuBarItems) ?? [.cpu, .gpu, .temperature, .network]
        self.metricItemSettings = try container.decodeIfPresent([MenuBarItem: MetricItemSettings].self, forKey: .metricItemSettings) ?? Self.defaultMetricItemSettings()
        self.samplingMode = try container.decodeIfPresent(SamplingMode.self, forKey: .samplingMode) ?? .normal
        self.showUnknownSensors = try container.decodeIfPresent(Bool.self, forKey: .showUnknownSensors) ?? false
        self.includeVPNInterfaces = try container.decodeIfPresent(Bool.self, forKey: .includeVPNInterfaces) ?? false
        self.includeExternalDisks = try container.decodeIfPresent(Bool.self, forKey: .includeExternalDisks) ?? false
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.temperatureUnit = try container.decodeIfPresent(TemperatureUnit.self, forKey: .temperatureUnit) ?? .celsius
        self.chartTimeWindow = try container.decodeIfPresent(ChartTimeWindow.self, forKey: .chartTimeWindow) ?? .realtime
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

public enum MenuBarItem: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case cpu
    case gpu
    case temperature
    case network
    case disk

    public var id: String { rawValue }
}

public enum SamplingMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case low
    case normal
    case high

    public var id: String { rawValue }
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
            return 5 * 60
        case .day:
            return 24 * 60 * 60
        case .week:
            return 7 * 24 * 60 * 60
        }
    }

    public var summaryLabel: String {
        switch self {
        case .realtime:
            return "Last 5m"
        case .day:
            return "Last 24h"
        case .week:
            return "Last 7d"
        }
    }
}
