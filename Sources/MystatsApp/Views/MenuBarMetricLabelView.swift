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

        let iconTextSpacing: CGFloat = display.menuLayout.isPaired ? 2 : 4

        HStack(spacing: iconTextSpacing) {
            if presentation.showsMenuBarIcon {
                Image(systemName: presentation.symbolName)
                    .symbolRenderingMode(.monochrome)
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
            .frame(
                width: peerTextWidth(presentation: presentation, itemSettings: itemSettings),
                alignment: .leading
            )
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
                .frame(width: peerLabelColumnWidth, alignment: .leading)
            Text(value.value)
                .foregroundStyle(.primary)
                .frame(width: peerValueColumnWidth, alignment: .trailing)
        }
        .font(.system(size: 8.4, weight: .semibold))
    }

    private func peerTextWidth(
        presentation: MetricPresentation,
        itemSettings: MetricItemSettings
    ) -> CGFloat {
        let iconWidth: CGFloat = presentation.showsMenuBarIcon ? 12 : 0
        let iconGap: CGFloat = presentation.showsMenuBarIcon ? 1 : 0
        let sparklineWidth: CGFloat = itemSettings.showsMenuBarSparkline ? presentation.menuSparklineWidth : 0
        let sparklineGap: CGFloat = itemSettings.showsMenuBarSparkline ? 4 : 0
        return max(
            presentation.menuWidth(showingSparkline: itemSettings.showsMenuBarSparkline)
                - iconWidth
                - iconGap
                - sparklineWidth
                - sparklineGap,
            32
        )
    }

    private var peerValueColumnWidth: CGFloat {
        37
    }

    private var peerLabelColumnWidth: CGFloat {
        9
    }
}
