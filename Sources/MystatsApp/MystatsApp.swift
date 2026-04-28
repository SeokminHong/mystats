import AppKit
import SwiftUI
import MystatsCore

@main
struct MystatsApp: App {
    private static let version = "0.2.0"

    @StateObject private var metricStore = AppRuntime.shared.metricStore
    @StateObject private var settingsStore = AppRuntime.shared.settingsStore

    init() {
        if Self.handleCommandLineInfo() {
            Foundation.exit(0)
        }

        #if DEBUG
        if let outputPath = Self.qaRenderOutputPath() {
            do {
                try StatusItemVisualQARenderer.render(to: URL(fileURLWithPath: outputPath))
                Foundation.exit(0)
            } catch {
                fputs("visual QA render failed: \(error)\n", stderr)
                Foundation.exit(1)
            }
        }
        #endif

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

    private static func handleCommandLineInfo() -> Bool {
        let arguments = Set(CommandLine.arguments.dropFirst())
        if arguments.contains("--version") {
            print("mystats \(version)")
            return true
        }

        guard arguments.contains("--help") || arguments.contains("-h") else {
            return false
        }

        print("""
        usage: mystats [--version] [--help] [--open-settings] [--open-metric=<metric>]

        options:
          --version             Print the installed version.
          --help, -h            Print this help.
          --open-settings       Launch the settings window.
          --open-metric=<name>  Open a metric popover for cpu, gpu, network, or disk.
        """)
        return true
    }

    private static func requestedMetricPopover() -> MenuBarItem? {
        CommandLine.arguments.compactMap { argument in
            guard argument.hasPrefix("--open-metric=") else {
                return nil
            }
            let value = String(argument.dropFirst("--open-metric=".count))
            let item = MenuBarItem(rawValue: value)
            return item?.isUserVisible == true ? item : nil
        }.first
    }

    #if DEBUG
    private static func qaRenderOutputPath() -> String? {
        CommandLine.arguments.compactMap { argument in
            guard argument.hasPrefix("--render-qa=") else {
                return nil
            }
            return String(argument.dropFirst("--render-qa=".count))
        }.first
    }
    #endif

    private static func afterLaunch(_ action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.async {
            Task { @MainActor in
                action()
            }
        }
    }
}
