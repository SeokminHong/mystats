import MystatsCore

struct MetricDisplaySnapshot {
    let primaryValue: String
    let secondaryValue: String?
    let menuLayout: MetricMenuLayout
    let status: MetricStatus
    let chartSeries: [MetricMenuChartSeries]

    var hasConfigurableSecondaryValue: Bool {
        menuLayout.hasConfigurableSecondaryValue
    }
}

struct MetricMenuChartSeries {
    let values: [Double]
}

enum MetricMenuLayout {
    case single(primary: String, secondary: String?, secondaryConfigurable: Bool)
    case paired(first: MetricMenuPeerValue, second: MetricMenuPeerValue)

    var isPaired: Bool {
        if case .paired = self {
            return true
        }
        return false
    }

    var hasConfigurableSecondaryValue: Bool {
        switch self {
        case .single(_, let secondary, let secondaryConfigurable):
            return secondaryConfigurable && secondary != nil
        case .paired:
            return false
        }
    }
}

struct MetricMenuPeerValue {
    let label: String
    let value: String
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
        let primary = PercentFormatter.short(cpu.totalUsage)
        let secondary = coreGroupSummary(cpu)

        return MetricDisplaySnapshot(
            primaryValue: primary,
            secondaryValue: secondary,
            menuLayout: .single(primary: primary, secondary: secondary, secondaryConfigurable: true),
            status: cpu.status,
            chartSeries: [MetricMenuChartSeries(values: history.compactMap { $0.cpu?.totalUsage })]
        )
    }

    private static func gpu(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricDisplaySnapshot {
        guard let gpu = snapshot.gpu else {
            return unavailable()
        }
        let primary = gpu.totalUsage.map(PercentFormatter.short) ?? "N/A"

        return MetricDisplaySnapshot(
            primaryValue: primary,
            secondaryValue: nil,
            menuLayout: .single(primary: primary, secondary: nil, secondaryConfigurable: false),
            status: gpu.status,
            chartSeries: [MetricMenuChartSeries(values: history.compactMap { $0.gpu?.totalUsage })]
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
        let primary = thermal.cpuCelsius.map {
            TemperatureFormatter.short($0, unit: settings.temperatureUnit)
        } ?? thermal.thermalState.rawValue.capitalized

        return MetricDisplaySnapshot(
            primaryValue: primary,
            secondaryValue: nil,
            menuLayout: .single(primary: primary, secondary: nil, secondaryConfigurable: false),
            status: thermal.status,
            chartSeries: [MetricMenuChartSeries(values: history.compactMap { $0.thermal?.cpuCelsius })]
        )
    }

    private static func network(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricDisplaySnapshot {
        guard let network = snapshot.network else {
            return unavailable()
        }
        let download = ByteRateFormatter.short(network.downloadBytesPerSecond)
        let upload = ByteRateFormatter.short(network.uploadBytesPerSecond)

        return MetricDisplaySnapshot(
            primaryValue: "↓\(download)",
            secondaryValue: "↑\(upload)",
            menuLayout: .paired(
                first: MetricMenuPeerValue(label: "↓", value: download),
                second: MetricMenuPeerValue(label: "↑", value: upload)
            ),
            status: network.status,
            chartSeries: [
                MetricMenuChartSeries(
                    values: history.compactMap { $0.network?.downloadBytesPerSecond }.map { Double($0) }
                ),
                MetricMenuChartSeries(
                    values: history.compactMap { $0.network?.uploadBytesPerSecond }.map { Double($0) }
                )
            ]
        )
    }

    private static func disk(snapshot: MetricSnapshot, history: [MetricSnapshot]) -> MetricDisplaySnapshot {
        guard let disk = snapshot.disk else {
            return unavailable()
        }
        let read = ByteRateFormatter.short(disk.readBytesPerSecond)
        let write = ByteRateFormatter.short(disk.writeBytesPerSecond)

        return MetricDisplaySnapshot(
            primaryValue: "R \(read)",
            secondaryValue: "W \(write)",
            menuLayout: .paired(
                first: MetricMenuPeerValue(label: "R", value: read),
                second: MetricMenuPeerValue(label: "W", value: write)
            ),
            status: disk.status,
            chartSeries: [
                MetricMenuChartSeries(
                    values: history.compactMap { $0.disk?.readBytesPerSecond }.map { Double($0) }
                ),
                MetricMenuChartSeries(
                    values: history.compactMap { $0.disk?.writeBytesPerSecond }.map { Double($0) }
                )
            ]
        )
    }

    private static func unavailable() -> MetricDisplaySnapshot {
        MetricDisplaySnapshot(
            primaryValue: "N/A",
            secondaryValue: nil,
            menuLayout: .single(primary: "N/A", secondary: nil, secondaryConfigurable: false),
            status: .unavailable(reason: "No sample"),
            chartSeries: []
        )
    }

    private static func coreGroupSummary(_ cpu: CPUMetrics) -> String? {
        guard let performance = cpu.performanceCoreAverage, let efficiency = cpu.efficiencyCoreAverage else {
            return nil
        }

        return "P\(PercentFormatter.short(performance)) E\(PercentFormatter.short(efficiency))"
    }
}
