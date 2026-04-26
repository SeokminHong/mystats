import SwiftUI
import MystatsCore

struct CPUSectionView: View {
    let metrics: CPUMetrics

    var body: some View {
        MetricSection(title: "CPU", status: metrics.status) {
            MetricRow(label: "Total", value: PercentFormatter.long(metrics.totalUsage))
            if let average = metrics.performanceCoreAverage {
                MetricRow(label: "P-cores", value: PercentFormatter.long(average))
            }
            if let average = metrics.efficiencyCoreAverage {
                MetricRow(label: "E-cores", value: PercentFormatter.long(average))
            }

            VStack(spacing: 6) {
                ForEach(metrics.perCoreUsage) { core in
                    CoreUsageRow(core: core)
                }
            }
            .padding(.top, 4)
        }
    }
}

struct GPUSectionView: View {
    let metrics: GPUMetrics

    var body: some View {
        MetricSection(title: "GPU", status: metrics.status) {
            MetricRow(label: "Total", value: metrics.totalUsage.map(PercentFormatter.long) ?? "Unsupported")
            MetricRow(label: "Detail", value: "Unsupported")
        }
    }
}

struct ThermalSectionView: View {
    let metrics: ThermalMetrics
    let settings: AppSettings

    var body: some View {
        MetricSection(title: "Temperature", status: metrics.status) {
            MetricRow(label: "CPU", value: temperature(metrics.cpuCelsius))
            MetricRow(label: "GPU", value: temperature(metrics.gpuCelsius))
            MetricRow(label: "SoC", value: temperature(metrics.socCelsius))
            MetricRow(label: "Thermal", value: metrics.thermalState.rawValue.capitalized)

            if settings.showUnknownSensors {
                ForEach(metrics.unknownSensors) { sensor in
                    MetricRow(label: sensor.label, value: temperature(sensor.celsius))
                }
            }
        }
    }

    private func temperature(_ celsius: Double?) -> String {
        celsius.map { TemperatureFormatter.long($0, unit: settings.temperatureUnit) } ?? "Unavailable"
    }
}

struct DiskSectionView: View {
    let metrics: DiskMetrics

    var body: some View {
        MetricSection(title: "Disk", status: metrics.status) {
            MetricRow(label: "Read", value: ByteRateFormatter.long(metrics.readBytesPerSecond))
            MetricRow(label: "Write", value: ByteRateFormatter.long(metrics.writeBytesPerSecond))
        }
    }
}

struct NetworkSectionView: View {
    let metrics: NetworkMetrics

    var body: some View {
        MetricSection(title: "Network", status: metrics.status) {
            MetricRow(label: "Download", value: ByteRateFormatter.long(metrics.downloadBytesPerSecond))
            MetricRow(label: "Upload", value: ByteRateFormatter.long(metrics.uploadBytesPerSecond))
        }
    }
}

private struct CoreUsageRow: View {
    let core: CoreUsage

    var body: some View {
        HStack(spacing: 8) {
            Text(coreLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            ProgressView(value: core.usage)
                .progressViewStyle(.linear)
            Text(PercentFormatter.long(core.usage))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
    }

    private var coreLabel: String {
        switch core.kind {
        case .performance:
            return "P\(core.id)"
        case .efficiency:
            return "E\(core.id)"
        case .unknown:
            return "C\(core.id)"
        }
    }
}

private struct MetricSection<Content: View>: View {
    let title: String
    let status: MetricStatus
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                StatusBadge(status: status)
            }
            content
        }
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}

private struct StatusBadge: View {
    let status: MetricStatus

    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private var label: String {
        switch status {
        case .available:
            return "Available"
        case .experimental:
            return "Experimental"
        case .unsupported:
            return "Unsupported"
        case .unavailable:
            return "Unavailable"
        }
    }
}

