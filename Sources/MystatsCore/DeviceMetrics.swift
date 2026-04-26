public struct GPUMetrics: Equatable, Sendable {
    public let totalUsage: Double?
    public let frequencyMHz: Double?
    public let status: MetricStatus

    public init(totalUsage: Double?, frequencyMHz: Double?, status: MetricStatus) {
        self.totalUsage = totalUsage
        self.frequencyMHz = frequencyMHz
        self.status = status
    }
}

public struct ThermalMetrics: Equatable, Sendable {
    public let cpuCelsius: Double?
    public let gpuCelsius: Double?
    public let socCelsius: Double?
    public let thermalState: ThermalStateLabel
    public let unknownSensors: [SensorReading]
    public let status: MetricStatus

    public init(
        cpuCelsius: Double?,
        gpuCelsius: Double?,
        socCelsius: Double?,
        thermalState: ThermalStateLabel,
        unknownSensors: [SensorReading],
        status: MetricStatus
    ) {
        self.cpuCelsius = cpuCelsius
        self.gpuCelsius = gpuCelsius
        self.socCelsius = socCelsius
        self.thermalState = thermalState
        self.unknownSensors = unknownSensors
        self.status = status
    }
}

public enum ThermalStateLabel: String, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unknown
}

public struct SensorReading: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let celsius: Double

    public init(id: String, label: String, celsius: Double) {
        self.id = id
        self.label = label
        self.celsius = celsius
    }
}

public struct DiskMetrics: Equatable, Sendable {
    public let readBytesPerSecond: UInt64
    public let writeBytesPerSecond: UInt64
    public let status: MetricStatus

    public init(readBytesPerSecond: UInt64, writeBytesPerSecond: UInt64, status: MetricStatus) {
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.status = status
    }
}

public struct NetworkMetrics: Equatable, Sendable {
    public let downloadBytesPerSecond: UInt64
    public let uploadBytesPerSecond: UInt64
    public let activeInterfaces: [NetworkInterfaceMetric]
    public let status: MetricStatus

    public init(
        downloadBytesPerSecond: UInt64,
        uploadBytesPerSecond: UInt64,
        activeInterfaces: [NetworkInterfaceMetric],
        status: MetricStatus
    ) {
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.activeInterfaces = activeInterfaces
        self.status = status
    }
}

public struct NetworkInterfaceMetric: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

