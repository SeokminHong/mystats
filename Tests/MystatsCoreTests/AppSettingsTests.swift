import Foundation
import Testing
@testable import MystatsCore

@Test func defaultSettingsMatchMVPMenuBarPolicy() {
    let settings = AppSettings()

    #expect(settings.menuBarItems == [.cpu, .gpu, .temperature, .network])
    #expect(settings.samplingMode == .normal)
    #expect(settings.showUnknownSensors == false)
    #expect(settings.includeVPNInterfaces == false)
    #expect(settings.includeExternalDisks == false)
    #expect(settings.temperatureUnit == .celsius)
    #expect(settings.chartTimeWindow == .realtime)
    #expect(settings.settings(for: .cpu).showsSecondaryValue)
    #expect(settings.settings(for: .cpu).showsMenuBarSparkline)
    #expect(settings.settings(for: .cpu).showsPopoverDetails)
}

@Test func settingsDecodeOlderPayloadWithMetricDefaults() throws {
    let data = """
    {
      "menuBarItems": ["cpu", "network"],
      "samplingMode": "normal",
      "showUnknownSensors": false,
      "includeVPNInterfaces": false,
      "includeExternalDisks": false,
      "launchAtLogin": false,
      "temperatureUnit": "celsius"
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(AppSettings.self, from: data)

    #expect(settings.menuBarItems == [MenuBarItem.cpu, MenuBarItem.network])
    #expect(settings.settings(for: MenuBarItem.network) == MetricItemSettings.default)
    #expect(settings.chartTimeWindow == .realtime)
}
