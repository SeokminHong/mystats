public enum MetricStatus: Equatable, Sendable {
    case available
    case experimental
    case unsupported
    case unavailable(reason: String)
}

