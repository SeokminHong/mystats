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

            let itemSettings = settings.settings(for: item)
            host.statusItem.length = item.presentation.menuWidth(
                showingSparkline: itemSettings.showsMenuBarSparkline
            )
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

enum StatusItemImageRenderer {
    static func image(
        item: MenuBarItem,
        display: MetricDisplaySnapshot,
        itemSettings: MetricItemSettings
    ) -> NSImage {
        let width = item.presentation.menuWidth(
            showingSparkline: itemSettings.showsMenuBarSparkline
        )
        let size = NSSize(width: width, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        if item.presentation.showsMenuBarIcon {
            drawSymbol(item, in: NSRect(x: 0, y: 4, width: 12, height: 12))
        }

        let chartWidth: CGFloat = itemSettings.showsMenuBarSparkline ? item.presentation.menuSparklineWidth : 0
        let textX: CGFloat = item.presentation.showsMenuBarIcon ? 15 : 1
        let textWidth = width - textX - chartWidth - 1

        switch display.menuLayout {
        case .single(let primary, let secondary, let secondaryConfigurable):
            let primaryLine = "\(item.presentation.title) \(primary)"
            if secondaryConfigurable, itemSettings.showsSecondaryValue, let secondary {
                drawText(primaryLine, in: NSRect(x: textX, y: 10, width: textWidth, height: 9), size: 8.8, color: .labelColor, weight: .semibold)
                drawText(secondary, in: NSRect(x: textX, y: 2, width: textWidth, height: 8), size: 7.5, color: .secondaryLabelColor, weight: .regular)
            } else {
                drawText(primaryLine, in: NSRect(x: textX, y: 5, width: textWidth, height: 10), size: 8.8, color: .labelColor, weight: .semibold)
            }

        case .paired(let first, let second):
            drawPeerValue(first, in: NSRect(x: textX, y: 10, width: textWidth, height: 9))
            drawPeerValue(second, in: NSRect(x: textX, y: 2, width: textWidth, height: 9))
        }

        if itemSettings.showsMenuBarSparkline {
            drawSparkline(
                display.chartSeries,
                in: NSRect(x: width - chartWidth, y: 3, width: chartWidth, height: 14),
                color: .labelColor
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

    private static func drawPeerValue(_ value: MetricMenuPeerValue, in rect: NSRect) {
        drawText(value.label, in: NSRect(x: rect.minX, y: rect.minY, width: 10, height: rect.height), size: 8.4, color: .secondaryLabelColor, weight: .semibold)
        drawText(value.value, in: NSRect(x: rect.minX + 12, y: rect.minY, width: rect.width - 12, height: rect.height), size: 8.4, color: .labelColor, weight: .semibold)
    }

    private static func drawSparkline(_ series: [MetricMenuChartSeries], in rect: NSRect, color: NSColor) {
        drawSparklineGrid(in: rect, color: color.withAlphaComponent(0.18))

        let sanitizedSeries = series
            .map { ChartDomainResolver.downsample($0.values.filter(\.isFinite), maxCount: 32) }
            .map { ChartDomainResolver.displayTrendValues(for: $0) }
            .filter { $0.count > 1 }
        guard !sanitizedSeries.isEmpty else {
            return
        }

        let plotRect = NSRect(
            x: rect.minX + 0.5,
            y: rect.minY + 1,
            width: max(rect.width - 1, 1),
            height: max(rect.height - 2, 1)
        )
        let plotRects = sparklinePlotRects(count: sanitizedSeries.count, in: plotRect)

        for (seriesIndex, values) in sanitizedSeries.enumerated() {
            let seriesRect = plotRects[seriesIndex]
            let axis = ChartDomainResolver.trendDomain(for: values)
            let range = max(axis.upper - axis.lower, 0.0001)
            let path = NSBezierPath()
            let xStep = seriesRect.width / CGFloat(values.count - 1)

            for (index, value) in values.enumerated() {
                let normalized = min(max((value - axis.lower) / range, 0), 1)
                let point = NSPoint(
                    x: seriesRect.minX + CGFloat(index) * xStep,
                    y: seriesRect.minY + CGFloat(normalized) * seriesRect.height
                )

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.line(to: point)
                }
            }

            if seriesIndex > 0 {
                let dash: [CGFloat] = [2, 2]
                path.setLineDash(dash, count: dash.count, phase: 0)
            }

            (seriesIndex == 0 ? color : color.withAlphaComponent(0.58)).setStroke()
            path.lineWidth = seriesIndex == 0 ? 1.2 : 1.05
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    private static func sparklinePlotRects(count: Int, in rect: NSRect) -> [NSRect] {
        guard count > 1 else {
            return [rect]
        }

        let gap: CGFloat = 1
        let laneHeight = max((rect.height - gap * CGFloat(count - 1)) / CGFloat(count), 1)
        return (0..<count).map { index in
            NSRect(
                x: rect.minX,
                y: rect.maxY - CGFloat(index + 1) * laneHeight - CGFloat(index) * gap,
                width: rect.width,
                height: laneHeight
            )
        }
    }

    private static func drawSparklineGrid(in rect: NSRect, color: NSColor) {
        color.setStroke()

        for y in [rect.minY + 0.5, rect.midY] {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
            path.lineWidth = 0.5
            path.stroke()
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
