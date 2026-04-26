import SwiftUI
import MystatsCore

struct MenuBarLabelView: View {
    let snapshot: MetricSnapshot
    let settings: AppSettings

    var body: some View {
        Text(labelText)
            .monospacedDigit()
    }

    private var labelText: String {
        let parts = settings.menuBarItems.compactMap { item -> String? in
            switch item {
            case .cpu:
                return snapshot.cpu.map { "CPU \(PercentFormatter.short($0.totalUsage))" }
            case .gpu:
                return snapshot.gpu?.totalUsage.map { "GPU \(PercentFormatter.short($0))" }
            case .temperature:
                return snapshot.thermal?.cpuCelsius.map { TemperatureFormatter.short($0, unit: settings.temperatureUnit) }
            case .network:
                guard let network = snapshot.network else {
                    return nil
                }
                return "↓\(ByteRateFormatter.short(network.downloadBytesPerSecond)) ↑\(ByteRateFormatter.short(network.uploadBytesPerSecond))"
            case .disk:
                guard let disk = snapshot.disk else {
                    return nil
                }
                return "R \(ByteRateFormatter.short(disk.readBytesPerSecond)) W \(ByteRateFormatter.short(disk.writeBytesPerSecond))"
            }
        }

        return parts.isEmpty ? "mystats" : parts.joined(separator: "  ")
    }
}

