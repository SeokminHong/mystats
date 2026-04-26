import SwiftUI
import MystatsCore

@main
struct MystatsApp: App {
    @StateObject private var metricStore = MetricStore()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(metricStore)
                .environmentObject(settingsStore)
                .frame(width: 360)
                .onAppear {
                    metricStore.startPreviewUpdates()
                }
        } label: {
            MenuBarLabelView(
                snapshot: metricStore.snapshot,
                settings: settingsStore.settings
            )
            .onAppear {
                metricStore.startPreviewUpdates()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settingsStore)
                .frame(width: 360)
                .padding()
        }
    }
}

