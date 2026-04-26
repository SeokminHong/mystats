import SwiftUI
import MystatsCore

struct ManagerLauncherView: View {
    @Environment(\.openWindow) private var openWindow
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
                openWindow(id: "manager")
            } label: {
                Label("Open Manager", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

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
