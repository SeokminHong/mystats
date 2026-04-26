import Foundation
import Combine
import MystatsCore

@MainActor
final class MetricStore: ObservableObject {
    @Published private(set) var snapshot: MetricSnapshot
    @Published private(set) var history: RingBuffer<MetricSnapshot>

    private var minuteArchive: [MetricSnapshot]
    private var previewTimer: Timer?

    init() {
        let initialSnapshot = PreviewMetricFactory.snapshot()
        self.snapshot = initialSnapshot
        var initialHistory = RingBuffer<MetricSnapshot>(capacity: 300)
        initialHistory.append(initialSnapshot)
        self.history = initialHistory
        self.minuteArchive = Self.seedMinuteArchive(endingAt: initialSnapshot.timestamp)
    }

    func startPreviewUpdates() {
        guard previewTimer == nil else {
            return
        }

        previewTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.apply(PreviewMetricFactory.snapshot())
            }
        }
    }

    func apply(_ snapshot: MetricSnapshot) {
        self.snapshot = snapshot
        var nextHistory = history
        nextHistory.append(snapshot)
        history = nextHistory
        appendMinuteRollup(snapshot)
    }

    func history(for window: ChartTimeWindow) -> [MetricSnapshot] {
        let now = snapshot.timestamp
        switch window {
        case .realtime:
            return history.elements.filter { now.timeIntervalSince($0.timestamp) <= window.duration }
        case .day:
            let cutoff = now.addingTimeInterval(-window.duration)
            return minuteArchive.filter { $0.timestamp >= cutoff } + history.elements.suffix(1)
        case .week:
            let cutoff = now.addingTimeInterval(-window.duration)
            return minuteArchive.filter { $0.timestamp >= cutoff } + history.elements.suffix(1)
        }
    }

    deinit {
        previewTimer?.invalidate()
    }

    private func appendMinuteRollup(_ snapshot: MetricSnapshot) {
        let minute = Self.minuteBucket(snapshot.timestamp)
        if let last = minuteArchive.last, Self.minuteBucket(last.timestamp) == minute {
            minuteArchive[minuteArchive.count - 1] = snapshot
        } else {
            minuteArchive.append(snapshot)
        }

        let cutoff = snapshot.timestamp.addingTimeInterval(-7 * 24 * 60 * 60)
        if let firstValid = minuteArchive.firstIndex(where: { $0.timestamp >= cutoff }), firstValid > 0 {
            minuteArchive.removeFirst(firstValid)
        }
    }

    private static func seedMinuteArchive(endingAt date: Date) -> [MetricSnapshot] {
        let end = minuteBucket(date)
        let count = 7 * 24 * 60
        return (0..<count).map { index in
            let timestamp = Date(timeIntervalSince1970: TimeInterval(end - (count - index) * 60))
            return PreviewMetricFactory.snapshot(at: timestamp)
        }
    }

    private static func minuteBucket(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 60)
    }
}
