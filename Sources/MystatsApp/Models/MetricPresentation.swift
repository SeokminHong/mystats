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
    let peerLayout: MetricPeerLayout

    init(
        title: String,
        symbolName: String,
        menuWidth: CGFloat,
        compactMenuWidth: CGFloat? = nil,
        tint: Color,
        showsMenuBarIcon: Bool = true,
        menuSparklineWidth: CGFloat = 42,
        peerLayout: MetricPeerLayout = .compact
    ) {
        self.title = title
        self.symbolName = symbolName
        self.menuWidth = menuWidth
        self.compactMenuWidth = compactMenuWidth ?? max(menuWidth - menuSparklineWidth - 4, 44)
        self.tint = tint
        self.showsMenuBarIcon = showsMenuBarIcon
        self.menuSparklineWidth = menuSparklineWidth
        self.peerLayout = peerLayout
    }

    func menuWidth(showingSparkline: Bool) -> CGFloat {
        showingSparkline ? menuWidth : compactMenuWidth
    }
}

enum MetricPeerLayout {
    case compact
    case splitLabelAndValue
}

extension MenuBarItem {
    var presentation: MetricPresentation {
        switch self {
        case .cpu:
            return MetricPresentation(title: "CPU", symbolName: "cpu", menuWidth: 112, tint: .blue)
        case .gpu:
            return MetricPresentation(title: "GPU", symbolName: "display", menuWidth: 106, tint: .purple)
        case .temperature:
            return MetricPresentation(title: "Temp", symbolName: "thermometer.medium", menuWidth: 106, tint: .orange)
        case .network:
            return MetricPresentation(
                title: "Net",
                symbolName: "arrow.up.arrow.down",
                menuWidth: 116,
                compactMenuWidth: 70,
                tint: .green,
                menuSparklineWidth: 42,
                peerLayout: .splitLabelAndValue
            )
        case .disk:
            return MetricPresentation(
                title: "Disk",
                symbolName: "internaldrive",
                menuWidth: 128,
                tint: .teal,
                menuSparklineWidth: 42,
                peerLayout: .splitLabelAndValue
            )
        }
    }
}
