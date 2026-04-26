import Foundation
import SwiftUI
import MystatsCore

struct MetricHistoryDetail {
    let currentPrimary: String
    let currentSecondary: String?
    let windowLabel: String
    let sampleCount: Int
    let series: [MetricChartSeries]
    let stats: [MetricSummaryStat]
    let detailRows: [MetricDetailRow]
}

struct MetricChartSeries: Identifiable {
    let id: String
    let label: String
    let values: [Double]
    let tint: Color
    let formattedCurrent: String
}

struct MetricSummaryStat: Identifiable {
    let id: String
    let label: String
    let value: String
}

struct MetricDetailRow: Identifiable {
    let id: String
    let label: String
    let value: String
}

enum MetricHistoryResolver {
    static func resolve(
        item: MenuBarItem,
        snapshot: MetricSnapshot,
        history: [MetricSnapshot],
        settings: AppSettings
    ) -> MetricHistoryDetail {
        switch item {
        case .cpu:
            return cpu(snapshot: snapshot, history: history)
        case .gpu:
            return gpu(snapshot: snapshot, history: history)
        case .temperature:
            return temperature(snapshot: snapshot, history: history, settings: settings)
        case .network:
            return network(snapshot: snapshot, history: history)
        case .disk:
            return disk(snapshot: snapshot, history: history)
        }
    }

    private static func cpu(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricHistoryDetail {
        let values = history.compactMap { $0.cpu?.totalUsage }
        let cpu = snapshot.cpu
        let pAverage = cpu?.performanceCoreAverage.map(PercentFormatter.long) ?? "Unavailable"
        let eAverage = cpu?.efficiencyCoreAverage.map(PercentFormatter.long) ?? "Unavailable"

        return MetricHistoryDetail(
            currentPrimary: cpu.map { PercentFormatter.long($0.totalUsage) } ?? "Unavailable",
            currentSecondary: "P \(pAverage)  E \(eAverage)",
            windowLabel: windowLabel(history),
            sampleCount: values.count,
            series: [
                MetricChartSeries(
                    id: "cpu-total",
                    label: "Total",
                    values: values,
                    tint: .blue,
                    formattedCurrent: values.last.map(PercentFormatter.long) ?? "N/A"
                )
            ],
            stats: percentStats(values),
            detailRows: [
                MetricDetailRow(id: "p-cores", label: "P-cores", value: pAverage),
                MetricDetailRow(id: "e-cores", label: "E-cores", value: eAverage),
                MetricDetailRow(id: "cores", label: "Logical cores", value: "\(cpu?.perCoreUsage.count ?? 0)"),
                MetricDetailRow(id: "busiest-core", label: "Busiest core", value: busiestCoreLabel(cpu))
            ]
        )
    }

    private static func gpu(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricHistoryDetail {
        let values = history.compactMap { $0.gpu?.totalUsage }
        let gpu = snapshot.gpu
        let current = gpu?.totalUsage.map(PercentFormatter.long) ?? "Unsupported"

        return MetricHistoryDetail(
            currentPrimary: current,
            currentSecondary: gpu?.frequencyMHz.map { "\(Int($0.rounded())) MHz" },
            windowLabel: windowLabel(history),
            sampleCount: values.count,
            series: [
                MetricChartSeries(
                    id: "gpu-total",
                    label: "Total",
                    values: values,
                    tint: .purple,
                    formattedCurrent: current
                )
            ],
            stats: percentStats(values),
            detailRows: [
                MetricDetailRow(id: "detail", label: "Detail", value: "Unsupported"),
                MetricDetailRow(id: "frequency", label: "Frequency", value: gpu?.frequencyMHz.map { "\(Int($0.rounded())) MHz" } ?? "Unavailable")
            ]
        )
    }

    private static func temperature(
        snapshot: MetricSnapshot,
        history: [MetricSnapshot],
        settings: AppSettings
    ) -> MetricHistoryDetail {
        let cpuValues = history.compactMap { $0.thermal?.cpuCelsius }
        let gpuValues = history.compactMap { $0.thermal?.gpuCelsius }
        let socValues = history.compactMap { $0.thermal?.socCelsius }
        let thermal = snapshot.thermal
        let formatter: (Double) -> String = { TemperatureFormatter.long($0, unit: settings.temperatureUnit) }

        return MetricHistoryDetail(
            currentPrimary: thermal?.cpuCelsius.map(formatter) ?? thermal?.thermalState.rawValue.capitalized ?? "Unavailable",
            currentSecondary: thermal.map { "Thermal \($0.thermalState.rawValue.capitalized)" },
            windowLabel: windowLabel(history),
            sampleCount: max(cpuValues.count, max(gpuValues.count, socValues.count)),
            series: [
                MetricChartSeries(id: "thermal-cpu", label: "CPU", values: cpuValues, tint: .orange, formattedCurrent: cpuValues.last.map(formatter) ?? "N/A"),
                MetricChartSeries(id: "thermal-gpu", label: "GPU", values: gpuValues, tint: .pink, formattedCurrent: gpuValues.last.map(formatter) ?? "N/A"),
                MetricChartSeries(id: "thermal-soc", label: "SoC", values: socValues, tint: .red, formattedCurrent: socValues.last.map(formatter) ?? "N/A")
            ].filter { !$0.values.isEmpty },
            stats: numericStats(cpuValues, formatter: formatter),
            detailRows: [
                MetricDetailRow(id: "cpu", label: "CPU", value: thermal?.cpuCelsius.map(formatter) ?? "Unavailable"),
                MetricDetailRow(id: "gpu", label: "GPU", value: thermal?.gpuCelsius.map(formatter) ?? "Unavailable"),
                MetricDetailRow(id: "soc", label: "SoC", value: thermal?.socCelsius.map(formatter) ?? "Unavailable"),
                MetricDetailRow(id: "thermal-state", label: "Thermal state", value: thermal?.thermalState.rawValue.capitalized ?? "Unavailable"),
                MetricDetailRow(id: "unknown", label: "Unknown sensors", value: "\(thermal?.unknownSensors.count ?? 0)")
            ]
        )
    }

    private static func network(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricHistoryDetail {
        let downloadValues = history.compactMap { $0.network?.downloadBytesPerSecond }.map(Double.init)
        let uploadValues = history.compactMap { $0.network?.uploadBytesPerSecond }.map(Double.init)
        let network = snapshot.network

        return MetricHistoryDetail(
            currentPrimary: network.map { "↓\(ByteRateFormatter.long($0.downloadBytesPerSecond))" } ?? "Unavailable",
            currentSecondary: network.map { "↑\(ByteRateFormatter.long($0.uploadBytesPerSecond))" },
            windowLabel: windowLabel(history),
            sampleCount: max(downloadValues.count, uploadValues.count),
            series: [
                MetricChartSeries(id: "network-down", label: "Download", values: downloadValues, tint: .green, formattedCurrent: downloadValues.last.map(byteRate) ?? "N/A"),
                MetricChartSeries(id: "network-up", label: "Upload", values: uploadValues, tint: .mint, formattedCurrent: uploadValues.last.map(byteRate) ?? "N/A")
            ],
            stats: byteRateStats(downloadValues),
            detailRows: [
                MetricDetailRow(id: "download", label: "Download", value: network.map { ByteRateFormatter.long($0.downloadBytesPerSecond) } ?? "Unavailable"),
                MetricDetailRow(id: "upload", label: "Upload", value: network.map { ByteRateFormatter.long($0.uploadBytesPerSecond) } ?? "Unavailable"),
                MetricDetailRow(id: "interfaces", label: "Interfaces", value: network?.activeInterfaces.map(\.name).joined(separator: ", ") ?? "Unavailable")
            ]
        )
    }

    private static func disk(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricHistoryDetail {
        let readValues = history.compactMap { $0.disk?.readBytesPerSecond }.map(Double.init)
        let writeValues = history.compactMap { $0.disk?.writeBytesPerSecond }.map(Double.init)
        let disk = snapshot.disk

        return MetricHistoryDetail(
            currentPrimary: disk.map { "R \(ByteRateFormatter.long($0.readBytesPerSecond))" } ?? "Unavailable",
            currentSecondary: disk.map { "W \(ByteRateFormatter.long($0.writeBytesPerSecond))" },
            windowLabel: windowLabel(history),
            sampleCount: max(readValues.count, writeValues.count),
            series: [
                MetricChartSeries(id: "disk-read", label: "Read", values: readValues, tint: .teal, formattedCurrent: readValues.last.map(byteRate) ?? "N/A"),
                MetricChartSeries(id: "disk-write", label: "Write", values: writeValues, tint: .cyan, formattedCurrent: writeValues.last.map(byteRate) ?? "N/A")
            ],
            stats: byteRateStats(readValues),
            detailRows: [
                MetricDetailRow(id: "read", label: "Read", value: disk.map { ByteRateFormatter.long($0.readBytesPerSecond) } ?? "Unavailable"),
                MetricDetailRow(id: "write", label: "Write", value: disk.map { ByteRateFormatter.long($0.writeBytesPerSecond) } ?? "Unavailable")
            ]
        )
    }

    private static func percentStats(_ values: [Double]) -> [MetricSummaryStat] {
        numericStats(values, formatter: PercentFormatter.long)
    }

    private static func byteRateStats(_ values: [Double]) -> [MetricSummaryStat] {
        numericStats(values, formatter: byteRate)
    }

    private static func numericStats(_ values: [Double], formatter: (Double) -> String) -> [MetricSummaryStat] {
        guard !values.isEmpty else {
            return [
                MetricSummaryStat(id: "current", label: "Current", value: "N/A"),
                MetricSummaryStat(id: "min", label: "Min", value: "N/A"),
                MetricSummaryStat(id: "max", label: "Max", value: "N/A"),
                MetricSummaryStat(id: "avg", label: "Avg", value: "N/A")
            ]
        }

        let average = values.reduce(0, +) / Double(values.count)
        return [
            MetricSummaryStat(id: "current", label: "Current", value: formatter(values.last ?? 0)),
            MetricSummaryStat(id: "min", label: "Min", value: formatter(values.min() ?? 0)),
            MetricSummaryStat(id: "max", label: "Max", value: formatter(values.max() ?? 0)),
            MetricSummaryStat(id: "avg", label: "Avg", value: formatter(average))
        ]
    }

    private static func windowLabel(_ history: [MetricSnapshot]) -> String {
        guard let first = history.first?.timestamp, let last = history.last?.timestamp else {
            return "No history"
        }

        let seconds = max(Int(last.timeIntervalSince(first).rounded()), 0)
        return seconds < 60 ? "Last \(seconds)s" : "Last \(seconds / 60)m \(seconds % 60)s"
    }

    private static func busiestCoreLabel(_ cpu: CPUMetrics?) -> String {
        guard let core = cpu?.perCoreUsage.max(by: { $0.usage < $1.usage }) else {
            return "Unavailable"
        }

        let prefix: String
        switch core.kind {
        case .performance:
            prefix = "P"
        case .efficiency:
            prefix = "E"
        case .unknown:
            prefix = "C"
        }
        return "\(prefix)\(core.id) \(PercentFormatter.long(core.usage))"
    }

    private static func byteRate(_ value: Double) -> String {
        ByteRateFormatter.long(UInt64(max(value, 0)))
    }
}

