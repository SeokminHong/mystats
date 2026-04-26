import AppKit
import SwiftUI
import MystatsCore

@main
struct MystatsApp: App {
    @StateObject private var metricStore = AppRuntime.shared.metricStore
    @StateObject private var settingsStore = AppRuntime.shared.settingsStore

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        let runtime = AppRuntime.shared
        StatusBarController.shared.start(
            metricStore: runtime.metricStore,
            settingsStore: runtime.settingsStore
        )

        guard CommandLine.arguments.contains("--open-settings") else {
            if let item = Self.requestedMetricPopover() {
                Self.afterLaunch {
                    StatusBarController.shared.showPopover(for: item)
                }
            }
            return
        }

        Self.afterLaunch {
            AppWindowController.showSettings(
                metricStore: runtime.metricStore,
                settingsStore: runtime.settingsStore
            )
        }
    }

    var body: some Scene {
        Settings {
            ManagerWindowView()
                .environmentObject(settingsStore)
                .environmentObject(metricStore)
                .frame(width: 760, height: 560)
                .onAppear {
                    metricStore.startPreviewUpdates()
                }
        }
    }

    private static func requestedMetricPopover() -> MenuBarItem? {
        CommandLine.arguments.compactMap { argument in
            guard argument.hasPrefix("--open-metric=") else {
                return nil
            }
            let value = String(argument.dropFirst("--open-metric=".count))
            return MenuBarItem(rawValue: value)
        }.first
    }

    private static func afterLaunch(_ action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async {
            Task { @MainActor in
                action()
            }
        }
    }
}
