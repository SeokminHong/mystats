import Foundation
import Testing
@testable import MystatsCore

@Test func defaultSettingsMatchMVPMenuBarPolicy() {
    let settings = AppSettings()

    #expect(settings.menuBarItems == [.cpu, .gpu, .network])
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

@Test func settingsStripLegacyTemperatureMenuItem() throws {
    let data = """
    {
      "menuBarItems": ["cpu", "temperature", "gpu"],
      "metricItemSettings": {
        "temperature": {
          "showsSecondaryValue": false,
          "showsMenuBarSparkline": false,
          "showsPopoverDetails": false
        },
        "gpu": {
          "showsSecondaryValue": false,
          "showsMenuBarSparkline": true,
          "showsPopoverDetails": true
        }
      }
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(AppSettings.self, from: data)

    #expect(settings.menuBarItems == [.cpu, .gpu])
    #expect(settings.metricItemSettings[.temperature] == nil)
    #expect(settings.settings(for: .gpu).showsSecondaryValue == false)
}

@Test func settingsFallbackWhenOnlyLegacyTemperatureWasVisible() throws {
    let data = """
    {
      "menuBarItems": ["temperature"]
    }
    """.data(using: .utf8)!

    let settings = try JSONDecoder().decode(AppSettings.self, from: data)

    #expect(settings.menuBarItems == AppSettings.defaultMenuBarItems)
}

@Test func settingsDeduplicateMenuBarItemsWhenLoaded() throws {
    let settings = AppSettings(menuBarItems: [.cpu, .temperature, .cpu, .network])

    #expect(settings.menuBarItems == [.cpu, .network])
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

@Test func chartTimeWindowDurationsMatchDisplayPolicy() {
    #expect(ChartTimeWindow.realtime.duration == 15 * 60)
    #expect(ChartTimeWindow.day.duration == 24 * 60 * 60)
    #expect(ChartTimeWindow.week.duration == 7 * 24 * 60 * 60)
    #expect(ChartTimeWindow.realtime.summaryLabel == "Last 15m")
}
