import SwiftUI
import MystatsCore

@main
struct MystatsApp: App {
    @StateObject private var metricStore = MetricStore()
    @StateObject private var settingsStore = SettingsStore()

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

        WindowGroup("mystats Manager", id: "manager") {
            ManagerWindowView()
                .environmentObject(metricStore)
                .environmentObject(settingsStore)
                .frame(minWidth: 720, minHeight: 520)
                .onAppear {
                    metricStore.startPreviewUpdates()
                }
        }
        .defaultSize(width: 760, height: 560)

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
                .frame(width: 360)
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
