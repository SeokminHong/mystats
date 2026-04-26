import Foundation

public enum PreviewMetricFactory {
    public static func snapshot(at timestamp: Date = Date()) -> MetricSnapshot {
        let seconds = timestamp.timeIntervalSince1970
        let cpuTotal = utilization(seconds, seed: 11, base: 0.28, spread: 0.24)
        let gpuTotal = utilization(seconds, seed: 23, base: 0.18, spread: 0.18)
        let networkDown = byteRate(seconds, seed: 31, base: 2_800_000, spread: 7_500_000, spike: 16_000_000)
        let networkUp = byteRate(seconds, seed: 37, base: 600_000, spread: 1_400_000, spike: 3_000_000)

        return MetricSnapshot(
            timestamp: timestamp,
            cpu: CPUMetrics(
                totalUsage: cpuTotal,
                perCoreUsage: previewCores(seconds: seconds, cpuTotal: cpuTotal),
                performanceCoreAverage: min(cpuTotal + 0.09, 1.0),
                efficiencyCoreAverage: max(cpuTotal - 0.12, 0.0),
                status: .available
            ),
            gpu: GPUMetrics(
                totalUsage: gpuTotal,
                frequencyMHz: nil,
                status: .experimental
            ),
            thermal: ThermalMetrics(
                cpuCelsius: 52 + scaledWalk(seconds, interval: 60, seed: 41, spread: 18),
                gpuCelsius: 48 + scaledWalk(seconds, interval: 60, seed: 43, spread: 14),
                socCelsius: 54 + scaledWalk(seconds, interval: 60, seed: 47, spread: 12),
                thermalState: .nominal,
                unknownSensors: [],
                status: .experimental
            ),
            disk: DiskMetrics(
                readBytesPerSecond: byteRate(seconds, seed: 53, base: 3_000_000, spread: 12_000_000, spike: 24_000_000),
                writeBytesPerSecond: byteRate(seconds, seed: 59, base: 1_200_000, spread: 5_000_000, spike: 12_000_000),
                status: .available
            ),
            network: NetworkMetrics(
                downloadBytesPerSecond: networkDown,
                uploadBytesPerSecond: networkUp,
                activeInterfaces: [NetworkInterfaceMetric(id: "en0", name: "en0")],
                status: .available
            )
        )
    }

    private static func previewCores(seconds: TimeInterval, cpuTotal: Double) -> [CoreUsage] {
        (0..<8).map { index in
            let kind: CoreKind = index < 4 ? .performance : .efficiency
            let offset = scaledWalk(seconds + Double(index * 7), interval: 20, seed: 101 + index, spread: 0.28) - 0.14
            let usage = clamp(cpuTotal + offset, min: 0, max: 1)
            return CoreUsage(id: index, kind: kind, usage: usage)
        }
    }

    private static func utilization(_ seconds: TimeInterval, seed: Int, base: Double, spread: Double) -> Double {
        clamp(base + scaledWalk(seconds, interval: 15, seed: seed, spread: spread) - spread / 2, min: 0, max: 1)
    }

    private static func byteRate(
        _ seconds: TimeInterval,
        seed: Int,
        base: Double,
        spread: Double,
        spike: Double
    ) -> UInt64 {
        let normal = base + scaledWalk(seconds, interval: 20, seed: seed, spread: spread)
        let spikeValue = spikeEvent(seconds, seed: seed + 7) ? spike * normalizedNoise(bucket(seconds, interval: 45), seed: seed + 13) : 0
        return UInt64(max(normal + spikeValue, 0))
    }

    private static func scaledWalk(_ seconds: TimeInterval, interval: TimeInterval, seed: Int, spread: Double) -> Double {
        let bucket = bucket(seconds, interval: interval)
        let fraction = (seconds / interval) - Double(bucket)
        let eased = fraction * fraction * (3 - 2 * fraction)
        let start = normalizedNoise(bucket, seed: seed)
        let end = normalizedNoise(bucket + 1, seed: seed)
        return (start + (end - start) * eased) * spread
    }

    private static func spikeEvent(_ seconds: TimeInterval, seed: Int) -> Bool {
        normalizedNoise(bucket(seconds, interval: 45), seed: seed) > 0.84
    }

    private static func bucket(_ seconds: TimeInterval, interval: TimeInterval) -> Int {
        Int(floor(seconds / interval))
    }

    private static func normalizedNoise(_ bucket: Int, seed: Int) -> Double {
        var value = UInt64(bitPattern: Int64(bucket &* 1_103_515_245 &+ seed &* 12_345))
        value ^= value >> 33
        value &*= 0xff51afd7ed558ccd
        value ^= value >> 33
        value &*= 0xc4ceb9fe1a85ec53
        value ^= value >> 33
        return Double(value % 10_000) / 9_999
    }

    private static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }
}
