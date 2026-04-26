public protocol MetricCollector {
    associatedtype Output

    var name: String { get }
    var isAvailable: Bool { get }

    func sample() throws -> Output
}

