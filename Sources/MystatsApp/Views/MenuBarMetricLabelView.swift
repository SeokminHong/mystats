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

        HStack(spacing: 5) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(presentation.tint)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(display.primaryValue)
                    .font(.system(size: 11, weight: .medium))
                if let secondary = display.secondaryValue {
                    Text(secondary)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            SparklineChartView(values: display.chartValues, tint: presentation.tint)
                .frame(width: 28)
        }
        .frame(width: presentation.menuWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
}

