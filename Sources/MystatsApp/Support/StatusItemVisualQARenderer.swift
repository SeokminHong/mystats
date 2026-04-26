#if DEBUG
import AppKit
import SwiftUI
import MystatsCore

@MainActor
enum StatusItemVisualQARenderer {
    static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let history = previewHistory()
        guard let snapshot = history.last else {
            return
        }
        let settings = AppSettings(menuBarItems: MenuBarItem.allCases)

        try save(
            statusItemsImage(history: history, snapshot: snapshot, settings: settings, showingSparkline: true),
            to: directory.appendingPathComponent("status-items-chart-on.png")
        )
        try save(
            statusItemsImage(history: history, snapshot: snapshot, settings: settings, showingSparkline: false),
            to: directory.appendingPathComponent("status-items-chart-off.png")
        )

        for item in MenuBarItem.allCases {
            try save(
                historyChartImage(item: item, history: history, snapshot: snapshot, settings: settings),
                to: directory.appendingPathComponent("\(item.rawValue)-popover-chart.png")
            )
        }
    }

    private static func previewHistory() -> [MetricSnapshot] {
        let end = Date()
        return (0..<300).map { index in
            PreviewMetricFactory.snapshot(at: end.addingTimeInterval(TimeInterval(index - 299)))
        }
    }

    private static func statusItemsImage(
        history: [MetricSnapshot],
        snapshot: MetricSnapshot,
        settings: AppSettings,
        showingSparkline: Bool
    ) -> NSImage {
        let rowHeight: CGFloat = 38
        let labelWidth: CGFloat = 92
        let imageWidth: CGFloat = 280
        let image = NSImage(size: NSSize(width: imageWidth, height: rowHeight * CGFloat(MenuBarItem.allCases.count)))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: image.size).fill()

        for (index, item) in MenuBarItem.allCases.enumerated() {
            var metricSettings = settings.settings(for: item)
            metricSettings.showsMenuBarSparkline = showingSparkline
            let display = MetricDisplayResolver.resolve(
                item: item,
                snapshot: snapshot,
                history: history,
                settings: settings
            )
            let rendered = StatusItemImageRenderer.image(item: item, display: display, itemSettings: metricSettings)
            let y = image.size.height - CGFloat(index + 1) * rowHeight + 9

            drawQALabel(item.presentation.title, in: NSRect(x: 10, y: y + 2, width: labelWidth, height: 14))
            rendered.draw(in: NSRect(x: labelWidth, y: y, width: rendered.size.width, height: rendered.size.height))
        }

        return image
    }

    private static func historyChartImage(
        item: MenuBarItem,
        history: [MetricSnapshot],
        snapshot: MetricSnapshot,
        settings: AppSettings
    ) -> NSImage {
        let detail = MetricHistoryResolver.resolve(
            item: item,
            snapshot: snapshot,
            history: history,
            settings: settings
        )
        let rootView = HistoryChartView(series: detail.series, timeDomain: detail.timeDomain)
            .frame(width: 460, height: 124)
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor))
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 484, height: 148)
        hostingView.layoutSubtreeIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return NSImage(size: hostingView.bounds.size)
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)

        let image = NSImage(size: hostingView.bounds.size)
        image.addRepresentation(representation)
        return image
    }

    private static func drawQALabel(_ text: String, in rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func save(_ image: NSImage, to url: URL) throws {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        try pngData.write(to: url, options: .atomic)
    }
}
#endif
