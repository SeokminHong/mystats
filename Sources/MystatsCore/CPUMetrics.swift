public struct CPUMetrics: Equatable, Sendable {
    public let totalUsage: Double
    public let perCoreUsage: [CoreUsage]
    public let performanceCoreAverage: Double?
    public let efficiencyCoreAverage: Double?
    public let status: MetricStatus

    public init(
        totalUsage: Double,
        perCoreUsage: [CoreUsage],
        performanceCoreAverage: Double?,
        efficiencyCoreAverage: Double?,
        status: MetricStatus
    ) {
        self.totalUsage = totalUsage
        self.perCoreUsage = perCoreUsage
        self.performanceCoreAverage = performanceCoreAverage
        self.efficiencyCoreAverage = efficiencyCoreAverage
        self.status = status
    }
}

public struct CoreUsage: Identifiable, Equatable, Sendable {
    public let id: Int
    public let kind: CoreKind
    public let usage: Double

    public init(id: Int, kind: CoreKind, usage: Double) {
        self.id = id
        self.kind = kind
        self.usage = usage
    }
}

public enum CoreKind: Equatable, Sendable {
    case performance
    case efficiency
    case unknown
}

