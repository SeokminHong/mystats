import SwiftUI
import MystatsCore

struct ManagerWindowView: View {
    @EnvironmentObject private var metricStore: MetricStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        NavigationSplitView {
            List {
                Section("Menu Bar Metrics") {
                    ForEach(MenuBarItem.allCases) { item in
                        Toggle(isOn: menuBarItemBinding(item)) {
                            Label(item.presentation.title, systemImage: item.presentation.symbolName)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("mystats")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                        ForEach(MenuBarItem.allCases) { item in
                            ManagerMetricCard(
                                item: item,
                                enabled: menuBarItemBinding(item),
                                snapshot: metricStore.snapshot,
                                history: metricStore.history.elements,
                                settings: settingsStore.settings
                            )
                        }
                    }

                    ManagerSettingsPanel()
                        .environmentObject(settingsStore)
                }
                .padding(20)
            }
            .navigationTitle("Manager")
        }
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
                Text("Choose fixed-width menu bar metrics and review live previews.")
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

private struct ManagerMetricCard: View {
    let item: MenuBarItem
    @Binding var enabled: Bool
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]
    let settings: AppSettings

    var body: some View {
        let presentation = item.presentation
        let display = MetricDisplayResolver.resolve(
            item: item,
            snapshot: snapshot,
            history: history,
            settings: settings
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: presentation.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(presentation.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.headline)
                    Text(statusLabel(display.status))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            HStack(alignment: .center, spacing: 10) {
                MenuBarMetricLabelView(
                    item: item,
                    snapshot: snapshot,
                    history: history,
                    settings: settings
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fixed width")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(presentation.menuWidth)) pt")
                        .font(.caption.monospacedDigit())
                }
            }

            SparklineChartView(values: display.chartValues, tint: presentation.tint)
                .frame(height: 42)
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func statusLabel(_ status: MetricStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .experimental:
            return "Experimental"
        case .unsupported:
            return "Unsupported"
        case .unavailable:
            return "Unavailable"
        }
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
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

