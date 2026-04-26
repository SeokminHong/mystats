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
            .frame(maxWidth: .infinity, alignment: .leading)

            if itemSettings.showsMenuBarSparkline {
                SparklineChartView(values: display.chartValues, tint: .primary)
                    .frame(width: presentation.menuSparklineWidth)
            }
        }
        .frame(width: presentation.menuWidth, alignment: .leading)
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
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text(presentation.title)
                        .foregroundStyle(.secondary)
                    Text(primary)
                        .foregroundStyle(.primary)
                }
                .font(.system(size: 9, weight: .semibold))

                let secondaryLine = secondaryConfigurable && itemSettings.showsSecondaryValue
                    ? secondary
                    : statusLabel(display.status)
                Text(secondaryLine ?? statusLabel(display.status))
                    .font(.system(size: 7.5, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)

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
