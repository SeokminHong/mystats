import SwiftUI
import MystatsCore

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("Menu Bar") {
                ForEach(MenuBarItem.allCases) { item in
                    Toggle(item.title, isOn: menuBarItemBinding(item))
                }
            }

            Section("Sampling") {
                Picker("Mode", selection: $settingsStore.settings.samplingMode) {
                    ForEach(SamplingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Options") {
                Toggle("Launch at login", isOn: $settingsStore.settings.launchAtLogin)
                Toggle("Show unknown sensors", isOn: $settingsStore.settings.showUnknownSensors)
                Toggle("Include VPN interfaces", isOn: $settingsStore.settings.includeVPNInterfaces)
                Toggle("Include external disks", isOn: $settingsStore.settings.includeExternalDisks)

                Picker("Temperature", selection: $settingsStore.settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
            }
        }
    }

    private func menuBarItemBinding(_ item: MenuBarItem) -> Binding<Bool> {
        Binding {
            settingsStore.settings.menuBarItems.contains(item)
        } set: { enabled in
            settingsStore.setMenuBarItem(item, enabled: enabled)
        }
    }
}

