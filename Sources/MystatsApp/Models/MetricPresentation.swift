import SwiftUI
import MystatsCore

struct MetricPresentation {
    let title: String
    let symbolName: String
    let menuWidth: CGFloat
    let tint: Color
}

extension MenuBarItem {
    var presentation: MetricPresentation {
        switch self {
        case .cpu:
            return MetricPresentation(title: "CPU", symbolName: "cpu", menuWidth: 104, tint: .blue)
        case .gpu:
            return MetricPresentation(title: "GPU", symbolName: "display", menuWidth: 104, tint: .purple)
        case .temperature:
            return MetricPresentation(title: "Temp", symbolName: "thermometer.medium", menuWidth: 92, tint: .orange)
        case .network:
            return MetricPresentation(title: "Net", symbolName: "arrow.up.arrow.down", menuWidth: 142, tint: .green)
        case .disk:
            return MetricPresentation(title: "Disk", symbolName: "internaldrive", menuWidth: 142, tint: .teal)
        }
    }
}

