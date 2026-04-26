public struct RingBuffer<Element>: Equatable where Element: Equatable {
    private var storage: [Element] = []
    private let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
    }

    public var elements: [Element] {
        storage
    }

    public mutating func append(_ element: Element) {
        if storage.count == capacity {
            storage.removeFirst()
        }
        storage.append(element)
    }
}

