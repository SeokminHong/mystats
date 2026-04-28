import Foundation
import MystatsCore

enum PercentFormatter {
    static func short(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func long(_ value: Double) -> String {
        short(value)
    }
}

enum ByteRateFormatter {
    static func short(_ bytesPerSecond: UInt64) -> String {
        formatted(bytesPerSecond)
    }

    static func long(_ bytesPerSecond: UInt64) -> String {
        "\(formatted(bytesPerSecond))/s"
    }

    static func long(_ bytesPerSecond: Double) -> String {
        long(UInt64(max(0, bytesPerSecond.rounded())))
    }

    private static func formatted(_ bytesPerSecond: UInt64) -> String {
        guard bytesPerSecond > 0 else {
            return "0 KB"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytesPerSecond))
    }
}

enum TemperatureFormatter {
    static func short(_ celsius: Double, unit: TemperatureUnit) -> String {
        "\(Int(convert(celsius, to: unit).rounded()))°"
    }

    static func long(_ celsius: Double, unit: TemperatureUnit) -> String {
        "\(Int(convert(celsius, to: unit).rounded()))°\(unit.suffix)"
    }

    private static func convert(_ celsius: Double, to unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return celsius * 9 / 5 + 32
        }
    }
}
