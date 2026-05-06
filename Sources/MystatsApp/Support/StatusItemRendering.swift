import AppKit
import MystatsCore

final class StatusItemHost {
    let statusItem: NSStatusItem
    let target: StatusItemTarget
    private var lastRenderKey: StatusItemRenderKey?

    init(statusItem: NSStatusItem, target: StatusItemTarget) {
        self.statusItem = statusItem
        self.target = target
    }

    @MainActor
    func render(
        item: MenuBarItem,
        button: NSStatusBarButton,
        snapshot: MetricSnapshot,
        chartSeries: [MetricMenuChartSeries],
        settings: AppSettings
    ) {
        let display = MetricDisplayResolver.resolve(
            item: item,
            snapshot: snapshot,
            chartSeries: chartSeries,
            settings: settings
        )
        let itemSettings = settings.settings(for: item)
        let renderKey = StatusItemRenderKey(
            item: item,
            display: display,
            itemSettings: itemSettings
        )
        guard renderKey != lastRenderKey else {
            return
        }
        lastRenderKey = renderKey

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

private struct StatusItemRenderKey: Equatable {
    let item: MenuBarItem
    let primaryValue: String
    let secondaryValue: String?
    let menuLayout: MetricMenuLayout
    let status: MetricStatus
    let itemSettings: MetricItemSettings
    let chartSeries: [MetricMenuChartSeries]

    init(
        item: MenuBarItem,
        display: MetricDisplaySnapshot,
        itemSettings: MetricItemSettings
    ) {
        self.item = item
        self.primaryValue = display.primaryValue
        self.secondaryValue = display.secondaryValue
        self.menuLayout = display.menuLayout
        self.status = display.status
        self.itemSettings = itemSettings
        self.chartSeries = itemSettings.showsMenuBarSparkline ? display.chartSeries : []
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
        let chartGap: CGFloat = itemSettings.showsMenuBarSparkline ? 4 : 0
        let textX: CGFloat = item.presentation.showsMenuBarIcon ? (display.menuLayout.isPaired ? 16 : 13) : 1
        let textWidth = width - textX - chartWidth - chartGap
        let alignsTextTowardChart = itemSettings.showsMenuBarSparkline

        switch display.menuLayout {
        case .single(let primary, let secondary, let secondaryConfigurable):
            drawSingleValue(
                title: item.presentation.title,
                primary: primary,
                secondary: secondary,
                secondaryConfigurable: secondaryConfigurable,
                itemSettings: itemSettings,
                textX: textX,
                textWidth: textWidth,
                alignsTextTowardChart: alignsTextTowardChart
            )

        case .paired(let first, let second):
            let firstRect = NSRect(x: textX, y: 10, width: textWidth, height: 9)
            let secondRect = NSRect(x: textX, y: 2, width: textWidth, height: 9)
            let labelColor = item.presentation.showsMenuBarIcon ? templateSecondaryColor : templatePrimaryColor
            drawPeerValue(first, in: firstRect, labelColor: labelColor, alignsTowardChart: false)
            drawPeerValue(second, in: secondRect, labelColor: labelColor, alignsTowardChart: false)
        }

        if itemSettings.showsMenuBarSparkline {
            drawSparkline(
                display.chartSeries,
                in: NSRect(x: width - chartWidth, y: 3, width: chartWidth, height: 14),
                color: templatePrimaryColor
            )
        }

        image.isTemplate = true
        return image
    }

    private static func drawSingleValue(
        title: String,
        primary: String,
        secondary: String?,
        secondaryConfigurable: Bool,
        itemSettings: MetricItemSettings,
        textX: CGFloat,
        textWidth: CGFloat,
        alignsTextTowardChart: Bool
    ) {
        let primaryLine = "\(title) \(primary)"
        let primaryRect = compactTextRect(
            for: primaryLine,
            in: NSRect(x: textX, y: 10, width: textWidth, height: 9),
            size: 8.8,
            weight: .semibold,
            alignsTowardChart: alignsTextTowardChart
        )
        if secondaryConfigurable, itemSettings.showsSecondaryValue, let secondary {
            let secondaryRect = compactTextRect(
                for: secondary,
                in: NSRect(x: textX, y: 2, width: textWidth, height: 8),
                size: 7.5,
                weight: .regular,
                alignsTowardChart: alignsTextTowardChart
            )
            drawText(primaryLine, in: primaryRect, size: 8.8, color: templatePrimaryColor, weight: .semibold)
            drawText(secondary, in: secondaryRect, size: 7.5, color: templateSecondaryColor, weight: .regular)
        } else {
            let centeredRect = NSRect(x: primaryRect.minX, y: 5, width: primaryRect.width, height: 10)
            drawText(primaryLine, in: centeredRect, size: 8.8, color: templatePrimaryColor, weight: .semibold)
        }
    }

    private static func drawSymbol(_ item: MenuBarItem, in rect: NSRect) {
        guard let symbol = NSImage(systemSymbolName: item.presentation.symbolName, accessibilityDescription: nil) else {
            return
        }
        let template = symbol.copy() as? NSImage ?? symbol
        template.isTemplate = true
        templatePrimaryColor.set()
        template.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private static func drawText(
        _ text: String,
        in rect: NSRect,
        size: CGFloat,
        color: NSColor,
        weight: NSFont.Weight,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byClipping
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func drawPeerValue(
        _ value: MetricMenuPeerValue,
        in rect: NSRect,
        labelColor: NSColor,
        alignsTowardChart: Bool
    ) {
        let labelWidth = peerLabelColumnWidth
        let gap: CGFloat = 3
        let availableValueWidth = max(rect.width - labelWidth - gap, 1)
        let valueWidth = min(peerValueColumnWidth, availableValueWidth)
        let groupWidth = min(labelWidth + gap + valueWidth, rect.width)
        let groupX = alignsTowardChart ? max(rect.maxX - groupWidth, rect.minX) : rect.minX

        drawText(
            value.label,
            in: NSRect(x: groupX, y: rect.minY, width: labelWidth, height: rect.height),
            size: 8.4,
            color: labelColor,
            weight: .semibold
        )
        drawText(
            value.value,
            in: NSRect(x: groupX + labelWidth + gap, y: rect.minY, width: valueWidth, height: rect.height),
            size: 8.4,
            color: templatePrimaryColor,
            weight: .semibold,
            alignment: .right
        )
    }

    private static var peerValueColumnWidth: CGFloat {
        37
    }

    private static var peerLabelColumnWidth: CGFloat {
        9
    }

    private static var templatePrimaryColor: NSColor {
        NSColor.black
    }

    private static var templateSecondaryColor: NSColor {
        NSColor.black.withAlphaComponent(0.62)
    }

    private static func compactTextRect(
        for text: String,
        in rect: NSRect,
        size: CGFloat,
        weight: NSFont.Weight,
        alignsTowardChart: Bool
    ) -> NSRect {
        let measuredWidth = min(ceil(textWidth(text, size: size, weight: weight)), rect.width)
        guard alignsTowardChart else {
            return NSRect(x: rect.minX, y: rect.minY, width: measuredWidth, height: rect.height)
        }

        let maxLeadingShift: CGFloat = 6
        let rightAlignedX = max(rect.maxX - measuredWidth, rect.minX)
        let x = min(rightAlignedX, rect.minX + maxLeadingShift)
        return NSRect(x: x, y: rect.minY, width: measuredWidth, height: rect.height)
    }

    private static func textWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        ]
        return (text as NSString).size(withAttributes: attributes).width
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
            drawSparklineSeries(
                values,
                seriesIndex: seriesIndex,
                in: plotRects[seriesIndex],
                color: color
            )
        }
    }

    private static func drawSparklineSeries(
        _ values: [Double],
        seriesIndex: Int,
        in seriesRect: NSRect,
        color: NSColor
    ) {
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

final class StatusItemTarget: NSObject {
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
