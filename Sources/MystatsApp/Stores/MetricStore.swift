import Foundation
import Combine
import MystatsCore

@MainActor
final class MetricStore: ObservableObject {
    @Published private(set) var snapshot: MetricSnapshot
    @Published private(set) var history: RingBuffer<MetricSnapshot>

    private var previewTimer: Timer?

    init() {
        let initialSnapshot = PreviewMetricFactory.snapshot()
        self.snapshot = initialSnapshot
        var initialHistory = RingBuffer<MetricSnapshot>(capacity: 300)
        initialHistory.append(initialSnapshot)
        self.history = initialHistory
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
        history.append(snapshot)
    }

    deinit {
        previewTimer?.invalidate()
    }
}
