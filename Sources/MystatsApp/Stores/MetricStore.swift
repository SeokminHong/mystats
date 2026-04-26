import Foundation
import Combine
import MystatsCore

@MainActor
final class MetricStore: ObservableObject {
    private static let realtimeSampleCapacity = Int(ChartTimeWindow.realtime.duration)

    @Published private(set) var snapshot: MetricSnapshot
    @Published private(set) var history: RingBuffer<MetricSnapshot>

    private let persistentLogStore: PersistentMetricLogStore
    private var minuteArchive: [MetricSnapshot]
    private var previewTimer: Timer?

    init(persistentLogStore: PersistentMetricLogStore = PersistentMetricLogStore()) {
        self.persistentLogStore = persistentLogStore
        let initialSnapshot = PreviewMetricFactory.snapshot()
        let persistedSnapshots = persistentLogStore.loadSnapshots(
            since: initialSnapshot.timestamp.addingTimeInterval(-PersistentMetricLogStore.retention),
            now: initialSnapshot.timestamp
        )
        var initialHistory = RingBuffer<MetricSnapshot>(capacity: Self.realtimeSampleCapacity)

        let realtimeSeed = persistedSnapshots.isEmpty
            ? Self.seedRealtimeHistory(endingAt: initialSnapshot.timestamp, capacity: Self.realtimeSampleCapacity)
            : Array(persistedSnapshots.suffix(Self.realtimeSampleCapacity))
        for snapshot in realtimeSeed {
            initialHistory.append(snapshot)
        }

        self.history = initialHistory
        self.snapshot = initialHistory.elements.last ?? initialSnapshot
        self.minuteArchive = persistedSnapshots.isEmpty
            ? Self.seedMinuteArchive(endingAt: initialSnapshot.timestamp)
            : Self.minuteRollups(from: persistedSnapshots, endingAt: initialSnapshot.timestamp)
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
        persistentLogStore.append(snapshot)
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

    private static func seedRealtimeHistory(endingAt date: Date, capacity: Int) -> [MetricSnapshot] {
        let end = Int(date.timeIntervalSince1970)
        return (0..<capacity).map { index in
            let timestamp = Date(timeIntervalSince1970: TimeInterval(end - (capacity - index - 1)))
            return PreviewMetricFactory.snapshot(at: timestamp)
        }
    }

    private static func minuteRollups(from snapshots: [MetricSnapshot], endingAt date: Date) -> [MetricSnapshot] {
        var rollups: [MetricSnapshot] = []
        for snapshot in snapshots.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let last = rollups.last, minuteBucket(last.timestamp) == minuteBucket(snapshot.timestamp) {
                rollups[rollups.count - 1] = snapshot
            } else {
                rollups.append(snapshot)
            }
        }

        let cutoff = date.addingTimeInterval(-PersistentMetricLogStore.retention)
        if let firstValid = rollups.firstIndex(where: { $0.timestamp >= cutoff }), firstValid > 0 {
            rollups.removeFirst(firstValid)
        }
        return rollups
    }

    private static func minuteBucket(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 60)
    }
}
