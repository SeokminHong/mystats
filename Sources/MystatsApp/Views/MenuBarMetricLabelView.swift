import SwiftUI
import MystatsCore

struct MenuBarMetricLabelView: View {
    let item: MenuBarItem
    let snapshot: MetricSnapshot
    let history: [MetricSnapshot]
    let settings: AppSettings

    var body: some View {
        let presentation = item.presentation
        let display = MetricDisplayResolver.resolve(
            item: item,
            snapshot: snapshot,
            history: history,
            settings: settings
        )
        let itemSettings = settings.settings(for: item)

        HStack(spacing: 6) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 15)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text(presentation.title)
                        .foregroundStyle(.secondary)
                    Text(display.primaryValue)
                        .foregroundStyle(.primary)
                }
                .font(.system(size: 10, weight: .semibold))

                if itemSettings.showsSecondaryValue, let secondary = display.secondaryValue {
                    Text(secondary)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                } else {
                    Text(statusLabel(display.status))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)

            if itemSettings.showsMenuBarSparkline {
                SparklineChartView(values: display.chartValues, tint: presentation.tint)
                    .frame(width: 32)
            }
        }
        .frame(width: presentation.menuWidth, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func statusLabel(_ status: MetricStatus) -> String {
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
}
