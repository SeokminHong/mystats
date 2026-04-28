import AppKit
import SwiftUI
import MystatsCore

struct ManagerWindowView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var metricStore: MetricStore
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            TabView(selection: $selectedTab) {
                GeneralSettingsTab()
                    .environmentObject(settingsStore)
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }
                    .tag(SettingsTab.general)

                ForEach(MenuBarItem.allCases) { item in
                    MetricSettingsTab(item: item)
                        .environmentObject(settingsStore)
                        .environmentObject(metricStore)
                        .tabItem {
                            Label(item.presentation.title, systemImage: item.presentation.symbolName)
                        }
                        .tag(SettingsTab.metric(item))
                }
            }
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 560)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("mystats")
                    .font(.title2.bold())
                Text("Configure fixed-width metric items, popovers, and app controls.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

private enum SettingsTab: Hashable {
    case general
    case metric(MenuBarItem)
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("Sampling") {
                Picker("Sampling", selection: $settingsStore.settings.samplingMode) {
                    ForEach(SamplingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Default chart window", selection: $settingsStore.settings.chartTimeWindow) {
                    Text("Realtime").tag(ChartTimeWindow.realtime)
                    Text("1 Day").tag(ChartTimeWindow.day)
                    Text("1 Week").tag(ChartTimeWindow.week)
                }
                .pickerStyle(.segmented)
            }

            Section("Collectors") {
                Toggle("Show unknown sensors", isOn: $settingsStore.settings.showUnknownSensors)
                Toggle("Include VPN interfaces", isOn: $settingsStore.settings.includeVPNInterfaces)
                Toggle("Include external disks", isOn: $settingsStore.settings.includeExternalDisks)

                Picker("Temperature unit", selection: $settingsStore.settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .frame(maxWidth: 260)
            }

            Section("App") {
                Toggle("Launch at login", isOn: $settingsStore.settings.launchAtLogin)

                Button(role: .destructive) {
                    AppWindowController.quit()
                } label: {
                    Label("Quit mystats", systemImage: "power")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }
}

private struct MetricSettingsTab: View {
    let item: MenuBarItem

    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var metricStore: MetricStore

    var body: some View {
        let presentation = item.presentation
        let display = MetricDisplayResolver.resolve(
            item: item,
            snapshot: metricStore.snapshot,
            history: metricStore.history.elements,
            settings: settingsStore.settings
        )
        let itemSettings = settingsStore.settings.settings(for: item)
        let menuWidth = presentation.menuWidth(showingSparkline: itemSettings.showsMenuBarSparkline)

        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: presentation.symbolName)
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(presentation.tint)
                        .frame(width: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(presentation.title)
                            .font(.headline)
                        Text(statusLabel(display.status))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    headerValue(display)
                }
            }

            Section("Menu Bar Item") {
                Toggle("Show in menu bar", isOn: menuBarItemBinding)
                    .disabled(!settingsStore.canDisableMenuBarItem(item) && settingsStore.isMenuBarItemEnabled(item))

                if display.hasConfigurableSecondaryValue {
                    Toggle("Show secondary value", isOn: metricSettingsBinding(\.showsSecondaryValue))
                }
                Toggle("Show menu bar chart", isOn: metricSettingsBinding(\.showsMenuBarSparkline))

                LabeledContent("Menu width") {
                    Text("\(Int(menuWidth)) pt")
                        .monospacedDigit()
                }

                MenuBarMetricLabelView(
                    item: item,
                    snapshot: metricStore.snapshot,
                    history: metricStore.history.elements,
                    settings: settingsStore.settings
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
            }

            Section("Popover") {
                Toggle("Show metric detail section", isOn: metricSettingsBinding(\.showsPopoverDetails))

                Text("The popover always includes current value, chart, summary stats, settings, and quit controls.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func headerValue(_ display: MetricDisplaySnapshot) -> some View {
        switch display.menuLayout {
        case .single(let primary, _, _):
            Text(primary)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
        case .paired(let first, let second):
            VStack(alignment: .trailing, spacing: 2) {
                peerHeaderValue(first)
                peerHeaderValue(second)
            }
        }
    }

    private func peerHeaderValue(_ value: MetricMenuPeerValue) -> some View {
        HStack(spacing: 5) {
            Text(value.label)
                .foregroundStyle(.secondary)
            Text(value.value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .monospacedDigit()
    }

    private var menuBarItemBinding: Binding<Bool> {
        Binding {
            settingsStore.isMenuBarItemEnabled(item)
        } set: { enabled in
            settingsStore.setMenuBarItem(item, enabled: enabled)
        }
    }

    private func metricSettingsBinding(
        _ keyPath: WritableKeyPath<MetricItemSettings, Bool>
    ) -> Binding<Bool> {
        Binding {
            settingsStore.metricItemSettings(for: item)[keyPath: keyPath]
        } set: { value in
            settingsStore.updateMetricItemSettings(for: item) { settings in
                settings[keyPath: keyPath] = value
            }
        }
    }

    private func statusLabel(_ status: MetricStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .experimental:
            return "Experimental"
        case .unsupported:
            return "Unsupported"
        case .unavailable(let reason):
            return "Unavailable: \(reason)"
        }
    }
}
