import MystatsCore

extension MenuBarItem {
    var title: String {
        switch self {
        case .cpu:
            return "CPU"
        case .gpu:
            return "GPU"
        case .temperature:
            return "Temperature"
        case .network:
            return "Network"
        case .disk:
            return "Disk"
        }
    }
}

extension SamplingMode {
    var title: String {
        switch self {
        case .low:
            return "Low"
        case .normal:
            return "Normal"
        case .high:
            return "High"
        }
    }
}

extension TemperatureUnit {
    var title: String {
        switch self {
        case .celsius:
            return "Celsius"
        case .fahrenheit:
            return "Fahrenheit"
        }
    }

    var suffix: String {
        switch self {
        case .celsius:
            return "C"
        case .fahrenheit:
            return "F"
        }
    }
}

