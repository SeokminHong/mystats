import SwiftUI
import MystatsCore

struct ManagerWindowView: View {
    @EnvironmentObject private var metricStore: MetricStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("mystats")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 10) {
                    Text("Menu Bar Metrics")
                        .font(.headline)

                    ForEach(MenuBarItem.allCases) { item in
                        Toggle(isOn: menuBarItemBinding(item)) {
                            Label(item.presentation.title, systemImage: item.presentation.symbolName)
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
            .frame(width: 230)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(.quaternary.opacity(0.35))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(MenuBarItem.allCases) { item in
                            ManagerMetricRow(
                                item: item,
                                enabled: menuBarItemBinding(item)
                            )
                            Divider()
                        }
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))

                    ManagerSettingsPanel()
                        .environmentObject(settingsStore)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 42, height: 42)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("mystats")
                    .font(.title2.bold())
                Text("Choose fixed-width menu bar metrics and lightweight app controls.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
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

private struct ManagerMetricRow: View {
    let item: MenuBarItem
    @Binding var enabled: Bool

    var body: some View {
        let presentation = item.presentation

        HStack(spacing: 12) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.headline)
                Text("Fixed menu width: \(Int(presentation.menuWidth)) pt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $enabled)
                .toggleStyle(.switch)
                .labelsHidden()

            Text(enabled ? "On" : "Off")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
        .frame(minHeight: 44)
    }
}

private struct ManagerSettingsPanel: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.headline)

            Picker("Sampling", selection: $settingsStore.settings.samplingMode) {
                ForEach(SamplingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                GridRow {
                    Toggle("Launch at login", isOn: $settingsStore.settings.launchAtLogin)
                    Toggle("Show unknown sensors", isOn: $settingsStore.settings.showUnknownSensors)
                }
                GridRow {
                    Toggle("Include VPN interfaces", isOn: $settingsStore.settings.includeVPNInterfaces)
                    Toggle("Include external disks", isOn: $settingsStore.settings.includeExternalDisks)
                }
            }

            Picker("Temperature", selection: $settingsStore.settings.temperatureUnit) {
                ForEach(TemperatureUnit.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }
            .frame(maxWidth: 260)

            Divider()

            HStack {
                Spacer()
                Button(role: .destructive) {
                    AppWindowController.quit()
                } label: {
                    Label("Quit mystats", systemImage: "power")
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
