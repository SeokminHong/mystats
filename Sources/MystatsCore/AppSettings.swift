import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var menuBarItems: [MenuBarItem]
    public var samplingMode: SamplingMode
    public var showUnknownSensors: Bool
    public var includeVPNInterfaces: Bool
    public var includeExternalDisks: Bool
    public var launchAtLogin: Bool
    public var temperatureUnit: TemperatureUnit

    public init(
        menuBarItems: [MenuBarItem] = [.cpu, .gpu, .temperature, .network],
        samplingMode: SamplingMode = .normal,
        showUnknownSensors: Bool = false,
        includeVPNInterfaces: Bool = false,
        includeExternalDisks: Bool = false,
        launchAtLogin: Bool = false,
        temperatureUnit: TemperatureUnit = .celsius
    ) {
        self.menuBarItems = menuBarItems
        self.samplingMode = samplingMode
        self.showUnknownSensors = showUnknownSensors
        self.includeVPNInterfaces = includeVPNInterfaces
        self.includeExternalDisks = includeExternalDisks
        self.launchAtLogin = launchAtLogin
        self.temperatureUnit = temperatureUnit
    }
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

