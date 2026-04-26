import Foundation

public enum PreviewMetricFactory {
    public static func snapshot(at timestamp: Date = Date()) -> MetricSnapshot {
        let phase = timestamp.timeIntervalSince1970
        let cpuTotal = wave(phase, base: 0.24, amplitude: 0.18, speed: 0.7)
        let gpuTotal = wave(phase, base: 0.16, amplitude: 0.12, speed: 0.45)
        let networkDown = UInt64(wave(phase, base: 6_000_000, amplitude: 5_000_000, speed: 0.33))
        let networkUp = UInt64(wave(phase, base: 900_000, amplitude: 600_000, speed: 0.41))

        return MetricSnapshot(
            timestamp: timestamp,
            cpu: CPUMetrics(
                totalUsage: cpuTotal,
                perCoreUsage: previewCores(phase: phase),
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
                cpuCelsius: 58 + wave(phase, base: 0, amplitude: 5, speed: 0.19),
                gpuCelsius: 51 + wave(phase, base: 0, amplitude: 4, speed: 0.22),
                socCelsius: 60 + wave(phase, base: 0, amplitude: 3, speed: 0.15),
                thermalState: .nominal,
                unknownSensors: [],
                status: .experimental
            ),
            disk: DiskMetrics(
                readBytesPerSecond: UInt64(wave(phase, base: 12_000_000, amplitude: 10_000_000, speed: 0.27)),
                writeBytesPerSecond: UInt64(wave(phase, base: 4_000_000, amplitude: 3_000_000, speed: 0.31)),
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

    private static func previewCores(phase: TimeInterval) -> [CoreUsage] {
        (0..<8).map { index in
            let kind: CoreKind = index < 4 ? .performance : .efficiency
            let usage = wave(phase + Double(index), base: 0.24, amplitude: 0.22, speed: 0.5)
            return CoreUsage(id: index, kind: kind, usage: usage)
        }
    }

    private static func wave(_ phase: TimeInterval, base: Double, amplitude: Double, speed: Double) -> Double {
        max(base + amplitude * (sin(phase * speed) + 1) / 2, 0)
    }
}

