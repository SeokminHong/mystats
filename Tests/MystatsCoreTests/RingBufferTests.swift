import Testing
@testable import MystatsCore

@Test func ringBufferKeepsNewestElements() {
    var buffer = RingBuffer<Int>(capacity: 3)

    buffer.append(1)
    buffer.append(2)
    buffer.append(3)
    buffer.append(4)

    #expect(buffer.elements == [2, 3, 4])
}

