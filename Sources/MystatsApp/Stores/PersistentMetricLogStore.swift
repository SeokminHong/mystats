import Foundation
import MystatsCore
import OSLog

final class PersistentMetricLogStore {
    static let retention: TimeInterval = 7 * 24 * 60 * 60
    private static let cleanupInterval: TimeInterval = 6 * 60 * 60

    private let fileManager: FileManager
    private let directoryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dayFormatter: DateFormatter
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.seokmin.mystats",
        category: "MetricLog"
    )
    private var lastCleanupAt: Date?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directoryURL = Self.defaultDirectoryURL(fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        self.dayFormatter = formatter
    }

    func append(_ snapshot: MetricSnapshot) {
        cleanupIfNeeded()

        do {
            try ensureDirectoryExists()
            let record = PersistentMetricLogRecord(snapshot: snapshot)
            var data = try encoder.encode(record)
            data.append(0x0A)

            let fileURL = logFileURL(for: snapshot.timestamp)
            if !fileManager.fileExists(atPath: fileURL.path) {
                fileManager.createFile(atPath: fileURL.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            defer {
                try? handle.close()
            }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            logger.error("Failed to append metric log: \(String(describing: error), privacy: .public)")
        }
    }

    func loadSnapshots(since startDate: Date, now: Date = Date()) -> [MetricSnapshot] {
        cleanupIfNeeded(now: now, force: true)

        do {
            try ensureDirectoryExists()
            return try logFileURLs()
                .flatMap { try loadSnapshots(from: $0) }
                .filter { $0.timestamp >= startDate }
                .sorted { $0.timestamp < $1.timestamp }
        } catch {
            logger.error("Failed to load metric logs: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    func cleanupIfNeeded(now: Date = Date(), force: Bool = false) {
        guard force || lastCleanupAt.map({ now.timeIntervalSince($0) >= Self.cleanupInterval }) ?? true else {
            return
        }

        do {
            try ensureDirectoryExists()
            let cutoff = now.addingTimeInterval(-Self.retention)
            for fileURL in try logFileURLs() where shouldDelete(fileURL, cutoff: cutoff) {
                try fileManager.removeItem(at: fileURL)
            }
            lastCleanupAt = now
        } catch {
            logger.error("Failed to cleanup metric logs: \(String(describing: error), privacy: .public)")
        }
    }

    private func loadSnapshots(from fileURL: URL) throws -> [MetricSnapshot] {
        let data = try Data(contentsOf: fileURL)
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        return text.split(separator: "\n").compactMap { line in
            guard let lineData = String(line).data(using: .utf8) else {
                return nil
            }
            return try? decoder.decode(PersistentMetricLogRecord.self, from: lineData).snapshot
        }
    }

    private func shouldDelete(_ fileURL: URL, cutoff: Date) -> Bool {
        let day = fileURL.deletingPathExtension().lastPathComponent
        guard let date = dayFormatter.date(from: day) else {
            return false
        }
        return date.addingTimeInterval(24 * 60 * 60) < cutoff
    }

    private func logFileURLs() throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "jsonl" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func logFileURL(for date: Date) -> URL {
        directoryURL.appendingPathComponent("\(dayFormatter.string(from: date)).jsonl")
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private static func defaultDirectoryURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return baseURL
            .appendingPathComponent("mystats", isDirectory: true)
            .appendingPathComponent("MetricLogs", isDirectory: true)
    }
}

private struct PersistentMetricLogRecord: Codable {
    let timestamp: Date
    let cpu: CPULogRecord?
    let gpu: GPULogRecord?
    let thermal: ThermalLogRecord?
    let disk: DiskLogRecord?
    let network: NetworkLogRecord?

    init(snapshot: MetricSnapshot) {
        self.timestamp = snapshot.timestamp
        self.cpu = snapshot.cpu.map(CPULogRecord.init)
        self.gpu = snapshot.gpu.map(GPULogRecord.init)
        self.thermal = snapshot.thermal.map(ThermalLogRecord.init)
        self.disk = snapshot.disk.map(DiskLogRecord.init)
        self.network = snapshot.network.map(NetworkLogRecord.init)
    }

    var snapshot: MetricSnapshot {
        MetricSnapshot(
            timestamp: timestamp,
            cpu: cpu?.metrics,
            gpu: gpu?.metrics,
            thermal: thermal?.metrics,
            disk: disk?.metrics,
            network: network?.metrics
        )
    }
}

private struct CPULogRecord: Codable {
    let totalUsage: Double
    let perCoreUsage: [CoreLogRecord]
    let performanceCoreAverage: Double?
    let efficiencyCoreAverage: Double?
    let status: MetricStatusLogRecord

    init(_ metrics: CPUMetrics) {
        self.totalUsage = metrics.totalUsage
        self.perCoreUsage = metrics.perCoreUsage.map(CoreLogRecord.init)
        self.performanceCoreAverage = metrics.performanceCoreAverage
        self.efficiencyCoreAverage = metrics.efficiencyCoreAverage
        self.status = MetricStatusLogRecord(metrics.status)
    }

    var metrics: CPUMetrics {
        CPUMetrics(
            totalUsage: totalUsage,
            perCoreUsage: perCoreUsage.map(\.metrics),
            performanceCoreAverage: performanceCoreAverage,
            efficiencyCoreAverage: efficiencyCoreAverage,
            status: status.metrics
        )
    }
}

private struct CoreLogRecord: Codable {
    let id: Int
    let kind: String
    let usage: Double

    init(_ metrics: CoreUsage) {
        self.id = metrics.id
        self.kind = metrics.kind.logValue
        self.usage = metrics.usage
    }

    var metrics: CoreUsage {
        CoreUsage(id: id, kind: CoreKind(logValue: kind), usage: usage)
    }
}

private struct GPULogRecord: Codable {
    let totalUsage: Double?
    let frequencyMHz: Double?
    let status: MetricStatusLogRecord

    init(_ metrics: GPUMetrics) {
        self.totalUsage = metrics.totalUsage
        self.frequencyMHz = metrics.frequencyMHz
        self.status = MetricStatusLogRecord(metrics.status)
    }

    var metrics: GPUMetrics {
        GPUMetrics(totalUsage: totalUsage, frequencyMHz: frequencyMHz, status: status.metrics)
    }
}

private struct ThermalLogRecord: Codable {
    let cpuCelsius: Double?
    let gpuCelsius: Double?
    let socCelsius: Double?
    let thermalState: String
    let unknownSensors: [SensorLogRecord]
    let status: MetricStatusLogRecord

    init(_ metrics: ThermalMetrics) {
        self.cpuCelsius = metrics.cpuCelsius
        self.gpuCelsius = metrics.gpuCelsius
        self.socCelsius = metrics.socCelsius
        self.thermalState = metrics.thermalState.rawValue
        self.unknownSensors = metrics.unknownSensors.map(SensorLogRecord.init)
        self.status = MetricStatusLogRecord(metrics.status)
    }

    var metrics: ThermalMetrics {
        ThermalMetrics(
            cpuCelsius: cpuCelsius,
            gpuCelsius: gpuCelsius,
            socCelsius: socCelsius,
            thermalState: ThermalStateLabel(rawValue: thermalState) ?? .unknown,
            unknownSensors: unknownSensors.map(\.metrics),
            status: status.metrics
        )
    }
}

private struct SensorLogRecord: Codable {
    let id: String
    let label: String
    let celsius: Double

    init(_ metrics: SensorReading) {
        self.id = metrics.id
        self.label = metrics.label
        self.celsius = metrics.celsius
    }

    var metrics: SensorReading {
        SensorReading(id: id, label: label, celsius: celsius)
    }
}

private struct DiskLogRecord: Codable {
    let readBytesPerSecond: UInt64
    let writeBytesPerSecond: UInt64
    let status: MetricStatusLogRecord

    init(_ metrics: DiskMetrics) {
        self.readBytesPerSecond = metrics.readBytesPerSecond
        self.writeBytesPerSecond = metrics.writeBytesPerSecond
        self.status = MetricStatusLogRecord(metrics.status)
    }

    var metrics: DiskMetrics {
        DiskMetrics(
            readBytesPerSecond: readBytesPerSecond,
            writeBytesPerSecond: writeBytesPerSecond,
            status: status.metrics
        )
    }
}

private struct NetworkLogRecord: Codable {
    let downloadBytesPerSecond: UInt64
    let uploadBytesPerSecond: UInt64
    let activeInterfaces: [NetworkInterfaceLogRecord]
    let status: MetricStatusLogRecord

    init(_ metrics: NetworkMetrics) {
        self.downloadBytesPerSecond = metrics.downloadBytesPerSecond
        self.uploadBytesPerSecond = metrics.uploadBytesPerSecond
        self.activeInterfaces = metrics.activeInterfaces.map(NetworkInterfaceLogRecord.init)
        self.status = MetricStatusLogRecord(metrics.status)
    }

    var metrics: NetworkMetrics {
        NetworkMetrics(
            downloadBytesPerSecond: downloadBytesPerSecond,
            uploadBytesPerSecond: uploadBytesPerSecond,
            activeInterfaces: activeInterfaces.map(\.metrics),
            status: status.metrics
        )
    }
}

private struct NetworkInterfaceLogRecord: Codable {
    let id: String
    let name: String

    init(_ metrics: NetworkInterfaceMetric) {
        self.id = metrics.id
        self.name = metrics.name
    }

    var metrics: NetworkInterfaceMetric {
        NetworkInterfaceMetric(id: id, name: name)
    }
}

private struct MetricStatusLogRecord: Codable {
    let kind: String
    let reason: String?

    init(_ status: MetricStatus) {
        switch status {
        case .available:
            self.kind = "available"
            self.reason = nil
        case .experimental:
            self.kind = "experimental"
            self.reason = nil
        case .unsupported:
            self.kind = "unsupported"
            self.reason = nil
        case .unavailable(let reason):
            self.kind = "unavailable"
            self.reason = reason
        }
    }

    var metrics: MetricStatus {
        switch kind {
        case "available":
            return .available
        case "experimental":
            return .experimental
        case "unsupported":
            return .unsupported
        case "unavailable":
            return .unavailable(reason: reason ?? "No reason")
        default:
            return .unavailable(reason: "Unknown persisted status")
        }
    }
}

private extension CoreKind {
    init(logValue: String) {
        switch logValue {
        case "performance":
            self = .performance
        case "efficiency":
            self = .efficiency
        default:
            self = .unknown
        }
    }

    var logValue: String {
        switch self {
        case .performance:
            return "performance"
        case .efficiency:
            return "efficiency"
        case .unknown:
            return "unknown"
        }
    }
}
