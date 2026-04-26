import SwiftUI
import MystatsCore

struct PopoverView: View {
    @EnvironmentObject private var metricStore: MetricStore
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HeaderView(snapshot: metricStore.snapshot)

            if let cpu = metricStore.snapshot.cpu {
                CPUSectionView(metrics: cpu)
            }

            if let gpu = metricStore.snapshot.gpu {
                GPUSectionView(metrics: gpu)
            }

            if let thermal = metricStore.snapshot.thermal {
                ThermalSectionView(metrics: thermal, settings: settingsStore.settings)
            }

            if let disk = metricStore.snapshot.disk {
                DiskSectionView(metrics: disk)
            }

            if let network = metricStore.snapshot.network {
                NetworkSectionView(metrics: network)
            }
        }
        .padding(16)
    }
}

private struct HeaderView: View {
    let snapshot: MetricSnapshot

    var body: some View {
        HStack {
            Text("mystats")
                .font(.headline)
            Spacer()
            Text(snapshot.timestamp, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

