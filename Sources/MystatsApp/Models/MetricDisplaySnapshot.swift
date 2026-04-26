import MystatsCore

struct MetricDisplaySnapshot {
    let primaryValue: String
    let secondaryValue: String?
    let status: MetricStatus
    let chartValues: [Double]
}

enum MetricDisplayResolver {
    static func resolve(
        item: MenuBarItem,
        snapshot: MetricSnapshot,
        history: [MetricSnapshot],
        settings: AppSettings
    ) -> MetricDisplaySnapshot {
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

    private static func cpu(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricDisplaySnapshot {
        guard let cpu = snapshot.cpu else {
            return unavailable()
        }

        return MetricDisplaySnapshot(
            primaryValue: PercentFormatter.short(cpu.totalUsage),
            secondaryValue: nil,
            status: cpu.status,
            chartValues: history.compactMap { $0.cpu?.totalUsage }
        )
    }

    private static func gpu(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricDisplaySnapshot {
        guard let gpu = snapshot.gpu else {
            return unavailable()
        }

        return MetricDisplaySnapshot(
            primaryValue: gpu.totalUsage.map(PercentFormatter.short) ?? "N/A",
            secondaryValue: nil,
            status: gpu.status,
            chartValues: history.compactMap { $0.gpu?.totalUsage }
        )
    }

    private static func temperature(
        snapshot: MetricSnapshot,
        history: [MetricSnapshot],
        settings: AppSettings
    ) -> MetricDisplaySnapshot {
        guard let thermal = snapshot.thermal else {
            return unavailable()
        }

        return MetricDisplaySnapshot(
            primaryValue: thermal.cpuCelsius.map { TemperatureFormatter.short($0, unit: settings.temperatureUnit) } ?? thermal.thermalState.rawValue.capitalized,
            secondaryValue: nil,
            status: thermal.status,
            chartValues: history.compactMap { $0.thermal?.cpuCelsius }
        )
    }

    private static func network(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricDisplaySnapshot {
        guard let network = snapshot.network else {
            return unavailable()
        }

        return MetricDisplaySnapshot(
            primaryValue: "↓\(ByteRateFormatter.short(network.downloadBytesPerSecond))",
            secondaryValue: "↑\(ByteRateFormatter.short(network.uploadBytesPerSecond))",
            status: network.status,
            chartValues: history.compactMap { $0.network?.downloadBytesPerSecond }.map(Double.init)
        )
    }

    private static func disk(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricDisplaySnapshot {
        guard let disk = snapshot.disk else {
            return unavailable()
        }

        return MetricDisplaySnapshot(
            primaryValue: "R \(ByteRateFormatter.short(disk.readBytesPerSecond))",
            secondaryValue: "W \(ByteRateFormatter.short(disk.writeBytesPerSecond))",
            status: disk.status,
            chartValues: history.compactMap { $0.disk?.readBytesPerSecond }.map(Double.init)
        )
    }

    private static func unavailable() -> MetricDisplaySnapshot {
        MetricDisplaySnapshot(
            primaryValue: "N/A",
            secondaryValue: nil,
            status: .unavailable(reason: "No sample"),
            chartValues: []
        )
    }
}

