import SwiftUI
import MystatsCore

struct ManagerLauncherView: View {
    @EnvironmentObject private var metricStore: MetricStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("mystats")
                        .font(.headline)
                    Text("\(settingsStore.settings.menuBarItems.count) metrics visible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                AppWindowController.showSettings(
                    metricStore: metricStore,
                    settingsStore: settingsStore
                )
            } label: {
                Label("Open Settings", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                AppWindowController.showManager(
                    metricStore: metricStore,
                    settingsStore: settingsStore
                )
            } label: {
                Label("Metric Manager", systemImage: "switch.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                AppWindowController.quit()
            } label: {
                Label("Quit mystats", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(MenuBarItem.allCases) { item in
                    HStack {
                        Image(systemName: item.presentation.symbolName)
                            .foregroundStyle(item.presentation.tint)
                            .frame(width: 18)
                        Text(item.presentation.title)
                        Spacer()
                        Text(settingsStore.settings.menuBarItems.contains(item) ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(14)
    }
}
