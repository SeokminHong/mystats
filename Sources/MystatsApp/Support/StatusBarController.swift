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

    private override init() {
        super.init()
    }

    func start(metricStore: MetricStore, settingsStore: SettingsStore) {
        guard self.metricStore == nil else {
            return
        }

        self.metricStore = metricStore
        self.settingsStore = settingsStore
        metricStore.startPreviewUpdates()
        syncStatusItems()
        renderStatusItems()

        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncStatusItems()
                    self?.renderStatusItems()
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

            host.statusItem.length = item.presentation.menuWidth
            host.render(
                item: item,
                button: button,
                snapshot: metricStore.snapshot,
                history: metricStore.history.elements,
                settings: settings
            )
        }
    }

    fileprivate func togglePopover(for item: MenuBarItem, relativeTo button: NSStatusBarButton) {
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
        popover.contentSize = NSSize(width: 460, height: 620)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: MetricPopoverView(item: item)
                .environmentObject(metricStore)
                .environmentObject(settingsStore)
                .frame(width: 460)
                .frame(maxHeight: 620)
        )
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        activePopover = popover
        activeItem = item
    }

    func showPopover(for item: MenuBarItem) {
        guard let button = statusItems[item]?.statusItem.button else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        togglePopover(for: item, relativeTo: button)
    }

    private func closePopover() {
        activePopover?.close()
        activePopover = nil
        activeItem = nil
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            activePopover = nil
            activeItem = nil
        }
    }
}

private final class StatusItemHost {
    let statusItem: NSStatusItem
    let target: StatusItemTarget

    init(statusItem: NSStatusItem, target: StatusItemTarget) {
        self.statusItem = statusItem
        self.target = target
    }

    @MainActor
    func render(
        item: MenuBarItem,
        button: NSStatusBarButton,
        snapshot: MetricSnapshot,
        history: [MetricSnapshot],
        settings: AppSettings
    ) {
        let display = MetricDisplayResolver.resolve(
            item: item,
            snapshot: snapshot,
            history: history,
            settings: settings
        )
        let itemSettings = settings.settings(for: item)
        button.image = StatusItemImageRenderer.image(
            item: item,
            display: display,
            itemSettings: itemSettings
        )
        button.imagePosition = .imageOnly
        button.lineBreakMode = .byClipping
        button.title = ""
        button.toolTip = [item.presentation.title, display.primaryValue, display.secondaryValue]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

private enum StatusItemImageRenderer {
    static func image(
        item: MenuBarItem,
        display: MetricDisplaySnapshot,
        itemSettings: MetricItemSettings
    ) -> NSImage {
        let width = item.presentation.menuWidth
        let size = NSSize(width: width, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        drawSymbol(item, in: NSRect(x: 1, y: 4, width: 14, height: 14))

        let primary = "\(item.presentation.title) \(display.primaryValue)"
        let secondary = itemSettings.showsSecondaryValue
            ? display.secondaryValue
            : statusLabel(display.status)
        let chartWidth: CGFloat = itemSettings.showsMenuBarSparkline ? 30 : 0
        let textWidth = width - 21 - chartWidth - 4
        drawText(primary, in: NSRect(x: 20, y: 10, width: textWidth, height: 10), size: 9.5, color: .labelColor, weight: .semibold)
        drawText(secondary ?? "", in: NSRect(x: 20, y: 1, width: textWidth, height: 9), size: 8, color: .secondaryLabelColor, weight: .regular)

        if itemSettings.showsMenuBarSparkline {
            drawSparkline(
                display.chartValues,
                in: NSRect(x: width - 31, y: 4, width: 27, height: 14),
                color: tintColor(for: item)
            )
        }

        return image
    }

    private static func drawSymbol(_ item: MenuBarItem, in rect: NSRect) {
        let symbol = NSImage(systemSymbolName: item.presentation.symbolName, accessibilityDescription: nil)
        symbol?.draw(in: rect)
    }

    private static func drawText(
        _ text: String,
        in rect: NSRect,
        size: CGFloat,
        color: NSColor,
        weight: NSFont.Weight
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byClipping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func drawSparkline(_ values: [Double], in rect: NSRect, color: NSColor) {
        let sanitized = values.filter(\.isFinite)
        guard sanitized.count > 1 else {
            return
        }

        let minValue = sanitized.min() ?? 0
        let maxValue = sanitized.max() ?? 1
        let range = max(maxValue - minValue, 0.0001)
        let path = NSBezierPath()
        let xStep = rect.width / CGFloat(sanitized.count - 1)

        for (index, value) in sanitized.enumerated() {
            let normalized = (value - minValue) / range
            let point = NSPoint(
                x: rect.minX + CGFloat(index) * xStep,
                y: rect.minY + CGFloat(normalized) * rect.height
            )
            index == 0 ? path.move(to: point) : path.line(to: point)
        }

        color.setStroke()
        path.lineWidth = 1.2
        path.stroke()
    }

    private static func statusLabel(_ status: MetricStatus) -> String {
        switch status {
        case .available:
            return "Live"
        case .experimental:
            return "Experimental"
        case .unsupported:
            return "Unsupported"
        case .unavailable:
            return "Unavailable"
        }
    }

    private static func tintColor(for item: MenuBarItem) -> NSColor {
        switch item {
        case .cpu:
            return .systemBlue
        case .gpu:
            return .systemPurple
        case .temperature:
            return .systemOrange
        case .network:
            return .systemGreen
        case .disk:
            return .systemTeal
        }
    }
}

private final class StatusItemTarget: NSObject {
    let item: MenuBarItem
    weak var controller: StatusBarController?

    init(item: MenuBarItem) {
        self.item = item
    }

    @MainActor
    @objc func performClick(_ sender: NSStatusBarButton) {
        controller?.togglePopover(for: item, relativeTo: sender)
    }
}
