import SwiftUI
import MystatsCore

@main
struct MystatsApp: App {
    @StateObject private var metricStore = AppRuntime.shared.metricStore
    @StateObject private var settingsStore = AppRuntime.shared.settingsStore

    init() {
        guard CommandLine.arguments.contains("--open-settings") else {
            return
        }

        Task { @MainActor in
            AppRuntime.shared.metricStore.startPreviewUpdates()
            AppWindowController.showSettings(
                metricStore: AppRuntime.shared.metricStore,
                settingsStore: AppRuntime.shared.settingsStore
            )
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ManagerLauncherView()
                .environmentObject(metricStore)
                .environmentObject(settingsStore)
                .frame(width: 260)
                .onAppear {
                    metricStore.startPreviewUpdates()
                }
        } label: {
            Label("mystats", systemImage: "chart.xyaxis.line")
                .labelStyle(.iconOnly)
                .frame(width: 28)
                .onAppear {
                    metricStore.startPreviewUpdates()
                }
        }
        .menuBarExtraStyle(.window)

        metricExtra(.cpu)
        metricExtra(.gpu)
        metricExtra(.temperature)
        metricExtra(.network)
        metricExtra(.disk)

        Settings {
            ManagerWindowView()
                .environmentObject(settingsStore)
                .environmentObject(metricStore)
                .frame(width: 720, height: 520)
                .onAppear {
                    metricStore.startPreviewUpdates()
                }
        }
    }

    @SceneBuilder
    private func metricExtra(_ item: MenuBarItem) -> some Scene {
        MenuBarExtra(isInserted: menuBarItemBinding(item)) {
            MetricPopoverView(item: item)
                .environmentObject(metricStore)
                .environmentObject(settingsStore)
                .frame(width: 440)
                .frame(maxHeight: 620)
                .onAppear {
                    metricStore.startPreviewUpdates()
                }
        } label: {
            MenuBarMetricLabelView(
                item: item,
                snapshot: metricStore.snapshot,
                history: metricStore.history.elements,
                settings: settingsStore.settings
            )
            .onAppear {
                metricStore.startPreviewUpdates()
            }
        }
        .menuBarExtraStyle(.window)
    }

    private func menuBarItemBinding(_ item: MenuBarItem) -> Binding<Bool> {
        Binding {
            settingsStore.settings.menuBarItems.contains(item)
        } set: { enabled in
            settingsStore.setMenuBarItem(item, enabled: enabled)
        }
    }
}
