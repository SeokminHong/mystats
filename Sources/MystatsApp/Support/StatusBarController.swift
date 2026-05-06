import AppKit
import Combine
import SwiftUI
import MystatsCore

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    static let shared = StatusBarController()

    private var metricStore: MetricStore?
    private var settingsStore: SettingsStore?
    private var cancellables: Set<AnyCancellable> = []
    private var statusItems: [MenuBarItem: StatusItemHost] = [:]
    private var activePopover: NSPopover?
    private var activeItem: MenuBarItem?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var appResignObserver: NSObjectProtocol?

    private override init() {
        super.init()
    }

    func start(metricStore: MetricStore, settingsStore: SettingsStore) {
        guard self.metricStore == nil else {
            return
        }

        self.metricStore = metricStore
        self.settingsStore = settingsStore
        metricStore.startPreviewUpdates { [weak self, weak settingsStore] in
            let settings = settingsStore?.settings
            return MetricPreviewUpdateConfiguration(
                includeVPNInterfaces: settings?.includeVPNInterfaces ?? false,
                samplingMode: settings?.samplingMode ?? .normal,
                isInteractive: self?.activePopover?.isShown == true
            )
        }
        syncStatusItems()
        renderStatusItems()

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncStatusItems()
                    self?.renderStatusItems()
                    self?.metricStore?.refreshPreviewUpdates()
                }
            }
            .store(in: &cancellables)

        metricStore.$history
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.renderStatusItems()
                }
            }
            .store(in: &cancellables)
    }

    private func syncStatusItems() {
        guard let settings = settingsStore?.settings else {
            return
        }

        let visibleItems = Set(settings.menuBarItems)
        for item in MenuBarItem.allCases where visibleItems.contains(item) && statusItems[item] == nil {
            statusItems[item] = makeStatusItem(for: item)
        }

        for item in statusItems.keys where !visibleItems.contains(item) {
            if activeItem == item {
                closePopover()
            }
            if let statusItem = statusItems[item]?.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItems[item] = nil
        }
    }

    private func makeStatusItem(for item: MenuBarItem) -> StatusItemHost {
        let statusItem = NSStatusBar.system.statusItem(withLength: item.presentation.menuWidth)
        let target = StatusItemTarget(item: item)
        target.controller = self

        if let button = statusItem.button {
            button.target = target
            button.action = #selector(StatusItemTarget.performClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = item.presentation.title
            button.imagePosition = .noImage
            button.title = ""
        }

        let host = StatusItemHost(statusItem: statusItem, target: target)
        statusItems[item] = host
        return host
    }

    private func renderStatusItems() {
        guard
            let metricStore,
            let settings = settingsStore?.settings
        else {
            return
        }

        for item in settings.menuBarItems {
            guard let host = statusItems[item], let button = host.statusItem.button else {
                continue
            }

            let itemSettings = settings.settings(for: item)
            host.statusItem.length = item.presentation.menuWidth(
                showingSparkline: itemSettings.showsMenuBarSparkline
            )
            host.render(
                item: item,
                button: button,
                snapshot: metricStore.snapshot,
                chartSeries: metricStore.menuBarChartSeries(for: item),
                settings: settings
            )
        }
    }

    func togglePopover(for item: MenuBarItem, relativeTo button: NSStatusBarButton) {
        guard let metricStore, let settingsStore else {
            return
        }

        if activeItem == item, activePopover?.isShown == true {
            closePopover()
            return
        }

        closePopover()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        let controller = PopoverHostingController(
            rootView: MetricPopoverView(item: item)
                .environmentObject(metricStore)
                .environmentObject(settingsStore)
        )
        popover.contentViewController = controller
        popover.contentSize = controller.preferredPopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        activePopover = popover
        activeItem = item
        metricStore.refreshPreviewUpdates(immediate: true)
        focusPopover(popover)
        startPopoverEventMonitoring()
    }

    func showPopover(for item: MenuBarItem) {
        guard let button = statusItems[item]?.statusItem.button else {
            return
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        togglePopover(for: item, relativeTo: button)
    }

    private func closePopover() {
        stopPopoverEventMonitoring()
        activePopover?.close()
        activePopover = nil
        activeItem = nil
        metricStore?.refreshPreviewUpdates()
    }

    private func focusPopover(_ popover: NSPopover) {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak popover] in
            guard
                let popover,
                popover.isShown,
                let window = popover.contentViewController?.view.window
            else {
                return
            }

            window.makeKey()
            window.makeFirstResponder(popover.contentViewController?.view)
        }
    }

    private func startPopoverEventMonitoring() {
        stopPopoverEventMonitoring()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleLocalPopoverEvent(event)
            }
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }

        appResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
    }

    private func stopPopoverEventMonitoring() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }

        if let appResignObserver {
            NotificationCenter.default.removeObserver(appResignObserver)
            self.appResignObserver = nil
        }
    }

    private func handleLocalPopoverEvent(_ event: NSEvent) {
        guard let popover = activePopover, popover.isShown else {
            stopPopoverEventMonitoring()
            return
        }

        if event.type == .keyDown, event.keyCode == 53 {
            closePopover()
            return
        }

        guard event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .otherMouseDown else {
            return
        }

        if event.window == popover.contentViewController?.view.window {
            return
        }

        if statusItems.values.contains(where: { $0.statusItem.button?.window == event.window }) {
            return
        }

        closePopover()
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            stopPopoverEventMonitoring()
            activePopover = nil
            activeItem = nil
            metricStore?.refreshPreviewUpdates()
        }
    }
}

final class PopoverHostingController<Content: View>: NSHostingController<Content> {
    func preferredPopoverSize() -> NSSize {
        view.frame = NSRect(
            x: 0,
            y: 0,
            width: MetricPopoverLayout.width,
            height: MetricPopoverLayout.maxHeight
        )
        view.layoutSubtreeIfNeeded()

        let fittingHeight = view.fittingSize.height
        let height = min(
            max(fittingHeight, MetricPopoverLayout.minHeight),
            MetricPopoverLayout.maxHeight
        )
        preferredContentSize = NSSize(width: MetricPopoverLayout.width, height: height)
        return preferredContentSize
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeKey()
        view.window?.makeFirstResponder(view)
    }
}
