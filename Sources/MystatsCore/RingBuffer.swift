public struct RingBuffer<Element>: Equatable where Element: Equatable {
    private var storage: [Element?]
    private var headIndex = 0
    private var count = 0
    private let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be positive")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    public var elements: [Element] {
        (0..<count).compactMap { offset in
            storage[(headIndex + offset) % capacity]
        }
    }

    public mutating func append(_ element: Element) {
        let insertIndex = (headIndex + count) % capacity
        if count == capacity {
            storage[headIndex] = element
            headIndex = (headIndex + 1) % capacity
        } else {
            storage[insertIndex] = element
            count += 1
        }
    }

    public static func == (lhs: RingBuffer<Element>, rhs: RingBuffer<Element>) -> Bool {
        lhs.elements == rhs.elements
    }
}
