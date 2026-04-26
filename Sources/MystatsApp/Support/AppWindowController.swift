import AppKit
import SwiftUI

@MainActor
enum AppWindowController {
    private static var settingsWindow: NSWindow?

    static func activate() {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.unhide(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    static func showSettings(metricStore: MetricStore, settingsStore: SettingsStore) {
        showManager(metricStore: metricStore, settingsStore: settingsStore)
    }

    static func showManager(metricStore: MetricStore, settingsStore: SettingsStore) {
        let window = settingsWindow ?? makeSettingsWindow(
            metricStore: metricStore,
            settingsStore: settingsStore
        )
        settingsWindow = window

        activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private static func makeSettingsWindow(
        metricStore: MetricStore,
        settingsStore: SettingsStore
    ) -> NSWindow {
        let rootView = ManagerWindowView()
            .environmentObject(settingsStore)
            .environmentObject(metricStore)
            .frame(minWidth: 760, minHeight: 560)

        let window = NSWindow(
            contentRect: initialSettingsWindowFrame(),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "mystats Settings"
        window.contentMinSize = NSSize(width: 760, height: 560)
        window.contentViewController = NSHostingController(rootView: rootView)
        window.isReleasedWhenClosed = false
        return window
    }

    private static func initialSettingsWindowFrame() -> NSRect {
        let size = NSSize(width: 760, height: 560)
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return NSRect(origin: NSPoint(x: 120, y: 120), size: size)
        }

        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        return NSRect(origin: origin, size: size)
    }

    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
