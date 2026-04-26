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
        let menuWidth = presentation.menuWidth(showingSparkline: itemSettings.showsMenuBarSparkline)

        HStack(spacing: 4) {
            if presentation.showsMenuBarIcon {
                Image(systemName: presentation.symbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(presentation.tint)
                    .frame(width: 12)
            }

            menuText(
                presentation: presentation,
                display: display,
                itemSettings: itemSettings
            )

            if itemSettings.showsMenuBarSparkline {
                SparklineChartView(series: display.chartSeries, tint: .primary)
                    .frame(width: presentation.menuSparklineWidth)
            }
        }
        .frame(width: menuWidth, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func menuText(
        presentation: MetricPresentation,
        display: MetricDisplaySnapshot,
        itemSettings: MetricItemSettings
    ) -> some View {
        switch display.menuLayout {
        case .single(let primary, let secondary, let secondaryConfigurable):
            let showsSecondary = secondaryConfigurable && itemSettings.showsSecondaryValue && secondary != nil

            if showsSecondary {
                VStack(alignment: .leading, spacing: 1) {
                    singlePrimaryRow(title: presentation.title, value: primary)

                    if let secondary {
                        Text(secondary)
                            .font(.system(size: 7.5, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            } else {
                singlePrimaryRow(title: presentation.title, value: primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

        case .paired(let first, let second):
            VStack(alignment: .leading, spacing: 1) {
                peerRow(first)
                peerRow(second)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.86)
        }
    }

    private func singlePrimaryRow(title: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 9, weight: .semibold))
    }

    private func peerRow(_ value: MetricMenuPeerValue) -> some View {
        HStack(spacing: 3) {
            Text(value.label)
                .foregroundStyle(.secondary)
                .frame(width: 9, alignment: .center)
            Text(value.value)
                .foregroundStyle(.primary)
        }
        .font(.system(size: 8.4, weight: .semibold))
    }

}
