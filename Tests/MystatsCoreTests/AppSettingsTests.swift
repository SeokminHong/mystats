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
}

