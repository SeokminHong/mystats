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

@Test func ringBufferMaintainsLogicalEqualityAfterWrap() {
    var wrapped = RingBuffer<Int>(capacity: 3)
    wrapped.append(1)
    wrapped.append(2)
    wrapped.append(3)
    wrapped.append(4)

    var direct = RingBuffer<Int>(capacity: 3)
    direct.append(2)
    direct.append(3)
    direct.append(4)

    #expect(wrapped == direct)
}
