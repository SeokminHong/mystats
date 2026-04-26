import SwiftUI
import MystatsCore

struct MetricPopoverView: View {
    let item: MenuBarItem

    @Environment(\.openWindow) private var openWindow
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

        VStack(alignment: .leading, spacing: 14) {
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
                    openWindow(id: "manager")
                } label: {
                    Label("Manage", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(display.primaryValue)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if let secondary = display.secondaryValue {
                    Text(secondary)
                        .font(.title3)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            SparklineChartView(values: display.chartValues, tint: presentation.tint)
                .frame(height: 54)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            metricDetail
        }
        .padding(16)
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

