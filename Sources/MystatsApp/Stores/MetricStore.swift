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
    private var menuBarChartHistory: MenuBarChartHistory
    private var previewTimer: Timer?
    private var previewConfigurationProvider: (() -> MetricPreviewUpdateConfiguration)?
    private var networkCollector = NetworkRateCollector()

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
        self.menuBarChartHistory = MenuBarChartHistory(capacity: Self.realtimeSampleCapacity)
        for snapshot in initialHistory.elements {
            self.menuBarChartHistory.append(snapshot)
        }
        self.minuteArchive = persistedSnapshots.isEmpty
            ? Self.seedMinuteArchive(endingAt: initialSnapshot.timestamp)
            : Self.minuteRollups(from: persistedSnapshots, endingAt: initialSnapshot.timestamp)
    }

    func startPreviewUpdates(
        configuration: @escaping () -> MetricPreviewUpdateConfiguration = {
            MetricPreviewUpdateConfiguration(includeVPNInterfaces: false, samplingMode: .normal, isInteractive: false)
        }
    ) {
        guard previewConfigurationProvider == nil else {
            return
        }

        previewConfigurationProvider = configuration
        scheduleNextPreviewUpdate()
    }

    func refreshPreviewUpdates(immediate: Bool = false) {
        guard previewConfigurationProvider != nil else {
            return
        }

        previewTimer?.invalidate()
        if immediate {
            applyScheduledPreviewSnapshot()
        } else {
            scheduleNextPreviewUpdate()
        }
    }

    private func scheduleNextPreviewUpdate() {
        guard let configuration = previewConfigurationProvider?() else {
            return
        }

        previewTimer?.invalidate()
        let interval = configuration.sampleInterval
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.applyScheduledPreviewSnapshot()
            }
        }
        timer.tolerance = max(interval * 0.2, 0.2)
        previewTimer = timer
    }

    private func applyScheduledPreviewSnapshot() {
        guard let configuration = previewConfigurationProvider?() else {
            return
        }

        applyPreviewSnapshot(includeVPNInterfaces: configuration.includeVPNInterfaces)
        scheduleNextPreviewUpdate()
    }

    func apply(_ snapshot: MetricSnapshot, persists: Bool = true) {
        self.snapshot = snapshot
        var nextHistory = history
        nextHistory.append(snapshot)
        history = nextHistory
        menuBarChartHistory.append(snapshot)
        appendMinuteRollup(snapshot)
        if persists {
            persistentLogStore.append(snapshot)
        }
    }

    func menuBarChartSeries(for item: MenuBarItem) -> [MetricMenuChartSeries] {
        menuBarChartHistory.series(for: item)
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

    private func applyPreviewSnapshot(includeVPNInterfaces: Bool) {
        let timestamp = Date()
        let network = networkCollector.sample(includeVPNInterfaces: includeVPNInterfaces)
        let snapshot = PreviewMetricFactory.snapshot(at: timestamp).replacingNetwork(network)

        apply(snapshot, persists: false)
        persistentLogStore.append(
            MetricSnapshot(
                timestamp: timestamp,
                cpu: nil,
                gpu: nil,
                thermal: nil,
                disk: nil,
                network: network
            )
        )
    }

    private static func seedMinuteArchive(endingAt date: Date) -> [MetricSnapshot] {
        let end = minuteBucket(date)
        let count = 7 * 24 * 60
        return (0..<count).map { index in
            let timestamp = Date(timeIntervalSince1970: TimeInterval(end - (count - index) * 60))
            return PreviewMetricFactory.snapshot(at: timestamp).replacingNetwork(nil)
        }
    }

    private static func seedRealtimeHistory(endingAt date: Date, capacity: Int) -> [MetricSnapshot] {
        let end = Int(date.timeIntervalSince1970)
        return (0..<capacity).map { index in
            let timestamp = Date(timeIntervalSince1970: TimeInterval(end - (capacity - index - 1)))
            return PreviewMetricFactory.snapshot(at: timestamp).replacingNetwork(nil)
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

struct MetricPreviewUpdateConfiguration {
    let includeVPNInterfaces: Bool
    let samplingMode: SamplingMode
    let isInteractive: Bool

    var sampleInterval: TimeInterval {
        samplingMode.sampleInterval(isInteractive: isInteractive)
    }
}

private struct MenuBarChartHistory {
    private var cpu: RingBuffer<Double>
    private var gpu: RingBuffer<Double>
    private var thermalCPU: RingBuffer<Double>
    private var networkDownload: RingBuffer<Double>
    private var networkUpload: RingBuffer<Double>
    private var diskRead: RingBuffer<Double>
    private var diskWrite: RingBuffer<Double>

    init(capacity: Int) {
        self.cpu = RingBuffer(capacity: capacity)
        self.gpu = RingBuffer(capacity: capacity)
        self.thermalCPU = RingBuffer(capacity: capacity)
        self.networkDownload = RingBuffer(capacity: capacity)
        self.networkUpload = RingBuffer(capacity: capacity)
        self.diskRead = RingBuffer(capacity: capacity)
        self.diskWrite = RingBuffer(capacity: capacity)
    }

    mutating func append(_ snapshot: MetricSnapshot) {
        if let value = snapshot.cpu?.totalUsage {
            cpu.append(value)
        }
        if let value = snapshot.gpu?.totalUsage {
            gpu.append(value)
        }
        if let value = snapshot.thermal?.cpuCelsius {
            thermalCPU.append(value)
        }
        if let value = snapshot.network?.downloadBytesPerSecond {
            networkDownload.append(Double(value))
        }
        if let value = snapshot.network?.uploadBytesPerSecond {
            networkUpload.append(Double(value))
        }
        if let value = snapshot.disk?.readBytesPerSecond {
            diskRead.append(Double(value))
        }
        if let value = snapshot.disk?.writeBytesPerSecond {
            diskWrite.append(Double(value))
        }
    }

    func series(for item: MenuBarItem) -> [MetricMenuChartSeries] {
        switch item {
        case .cpu:
            return [MetricMenuChartSeries(values: cpu.elements)]
        case .gpu:
            return [MetricMenuChartSeries(values: gpu.elements)]
        case .temperature:
            return [MetricMenuChartSeries(values: thermalCPU.elements)]
        case .network:
            return [
                MetricMenuChartSeries(values: networkDownload.elements),
                MetricMenuChartSeries(values: networkUpload.elements)
            ]
        case .disk:
            return [
                MetricMenuChartSeries(values: diskRead.elements),
                MetricMenuChartSeries(values: diskWrite.elements)
            ]
        }
    }
}
