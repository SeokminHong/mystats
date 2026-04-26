import SwiftUI
import MystatsCore

struct MetricPresentation {
    let title: String
    let symbolName: String
    let menuWidth: CGFloat
    let compactMenuWidth: CGFloat
    let tint: Color
    let showsMenuBarIcon: Bool
    let menuSparklineWidth: CGFloat

    init(
        title: String,
        symbolName: String,
        menuWidth: CGFloat,
        compactMenuWidth: CGFloat? = nil,
        tint: Color,
        showsMenuBarIcon: Bool = true,
        menuSparklineWidth: CGFloat = 22
    ) {
        self.title = title
        self.symbolName = symbolName
        self.menuWidth = menuWidth
        self.compactMenuWidth = compactMenuWidth ?? max(menuWidth - menuSparklineWidth - 4, 44)
        self.tint = tint
        self.showsMenuBarIcon = showsMenuBarIcon
        self.menuSparklineWidth = menuSparklineWidth
    }

    func menuWidth(showingSparkline: Bool) -> CGFloat {
        showingSparkline ? menuWidth : compactMenuWidth
    }
}

extension MenuBarItem {
    var presentation: MetricPresentation {
        switch self {
        case .cpu:
            return MetricPresentation(title: "CPU", symbolName: "cpu", menuWidth: 104, tint: .blue)
        case .gpu:
            return MetricPresentation(title: "GPU", symbolName: "display", menuWidth: 98, tint: .purple)
        case .temperature:
            return MetricPresentation(title: "Temp", symbolName: "thermometer.medium", menuWidth: 96, tint: .orange)
        case .network:
            return MetricPresentation(
                title: "Net",
                symbolName: "arrow.up.arrow.down",
                menuWidth: 132,
                tint: .green,
                showsMenuBarIcon: false,
                menuSparklineWidth: 72
            )
        case .disk:
            return MetricPresentation(title: "Disk", symbolName: "internaldrive", menuWidth: 150, tint: .teal, menuSparklineWidth: 64)
        }
    }
}
