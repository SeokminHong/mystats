import SwiftUI
import MystatsCore

struct MetricPopoverView: View {
    let item: MenuBarItem

    @EnvironmentObject private var metricStore: MetricStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        let presentation = item.presentation
        let display = MetricDisplayResolver.resolve(
            item: item,
            snapshot: metricStore.snapshot,
            history: metricStore.history.elements,
            settings: settingsStore.settings
        )
        let detail = MetricHistoryResolver.resolve(
            item: item,
            snapshot: metricStore.snapshot,
            history: metricStore.history.elements,
            settings: settingsStore.settings
        )
        let itemSettings = settingsStore.settings.settings(for: item)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(presentation: presentation, display: display)

                currentValue(detail)

                HistoryChartView(series: detail.series)

                summaryGrid(detail.stats)

                detailRows(detail.detailRows)

                if itemSettings.showsPopoverDetails {
                    metricDetail
                }
            }
            .padding(16)
        }
    }

    private func header(presentation: MetricPresentation, display: MetricDisplaySnapshot) -> some View {
        HStack(spacing: 10) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(presentation.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.headline)
                Text(statusLabel(display.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                AppWindowController.showSettings(
                    metricStore: metricStore,
                    settingsStore: settingsStore
                )
            } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                AppWindowController.quit()
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.bordered)
        }
    }

    private func currentValue(_ detail: MetricHistoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(detail.currentPrimary)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    if let secondary = detail.currentSecondary {
                        Text(secondary)
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(detail.windowLabel)
                    Text("\(detail.sampleCount) samples")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }

    private func summaryGrid(_ stats: [MetricSummaryStat]) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                ForEach(stats.prefix(4)) { stat in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stat.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(stat.value)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                }
            }
        }
    }

    private func detailRows(_ rows: [MetricDetailRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
            ForEach(rows) { row in
                HStack {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var metricDetail: some View {
        switch item {
        case .cpu:
            if let cpu = metricStore.snapshot.cpu {
                CPUSectionView(metrics: cpu)
            }
        case .gpu:
            if let gpu = metricStore.snapshot.gpu {
                GPUSectionView(metrics: gpu)
            }
        case .temperature:
            if let thermal = metricStore.snapshot.thermal {
                ThermalSectionView(metrics: thermal, settings: settingsStore.settings)
            }
        case .network:
            if let network = metricStore.snapshot.network {
                NetworkSectionView(metrics: network)
            }
        case .disk:
            if let disk = metricStore.snapshot.disk {
                DiskSectionView(metrics: disk)
            }
        }
    }

    private func statusLabel(_ status: MetricStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .experimental:
            return "Experimental"
        case .unsupported:
            return "Unsupported"
        case .unavailable(let reason):
            return "Unavailable: \(reason)"
        }
    }
}
