import Foundation

public struct MetricSnapshot: Equatable, Sendable {
    public let timestamp: Date
    public let cpu: CPUMetrics?
    public let gpu: GPUMetrics?
    public let thermal: ThermalMetrics?
    public let disk: DiskMetrics?
    public let network: NetworkMetrics?

    public init(
        timestamp: Date,
        cpu: CPUMetrics?,
        gpu: GPUMetrics?,
        thermal: ThermalMetrics?,
        disk: DiskMetrics?,
        network: NetworkMetrics?
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.gpu = gpu
        self.thermal = thermal
        self.disk = disk
        self.network = network
    }
}

public extension MetricSnapshot {
    static func placeholder(timestamp: Date = Date()) -> MetricSnapshot {
        MetricSnapshot(
            timestamp: timestamp,
            cpu: nil,
            gpu: nil,
            thermal: nil,
            disk: nil,
            network: nil
        )
    }
}

