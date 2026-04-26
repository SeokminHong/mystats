import Darwin
import Foundation
import MystatsCore

struct NetworkRateCollector {
    private var previousSample: NetworkCounterSample?

    mutating func sample(includeVPNInterfaces: Bool) -> NetworkMetrics {
        let currentSample = NetworkCounterSample.capture(includeVPNInterfaces: includeVPNInterfaces)
        defer {
            previousSample = currentSample
        }

        guard
            let previousSample,
            currentSample.timestamp > previousSample.timestamp
        else {
            return NetworkMetrics(
                downloadBytesPerSecond: 0,
                uploadBytesPerSecond: 0,
                activeInterfaces: currentSample.interfaces,
                status: .available
            )
        }

        let elapsed = currentSample.timestamp.timeIntervalSince(previousSample.timestamp)
        let downloadDelta = currentSample.receivedBytes.subtractingReportingWrap(previousSample.receivedBytes)
        let uploadDelta = currentSample.sentBytes.subtractingReportingWrap(previousSample.sentBytes)

        return NetworkMetrics(
            downloadBytesPerSecond: UInt64(Double(downloadDelta) / elapsed),
            uploadBytesPerSecond: UInt64(Double(uploadDelta) / elapsed),
            activeInterfaces: currentSample.interfaces,
            status: .available
        )
    }
}

private struct NetworkCounterSample {
    let timestamp: Date
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let interfaces: [NetworkInterfaceMetric]

    static func capture(includeVPNInterfaces: Bool) -> NetworkCounterSample {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let firstAddress = interfaceAddresses else {
            return NetworkCounterSample(timestamp: Date(), receivedBytes: 0, sentBytes: 0, interfaces: [])
        }
        defer {
            freeifaddrs(interfaceAddresses)
        }

        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0
        var interfacesByName: [String: NetworkInterfaceMetric] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let address = cursor {
            defer {
                cursor = address.pointee.ifa_next
            }

            guard
                let socketAddress = address.pointee.ifa_addr,
                socketAddress.pointee.sa_family == UInt8(AF_LINK),
                let dataPointer = address.pointee.ifa_data
            else {
                continue
            }

            let name = String(cString: address.pointee.ifa_name)
            guard shouldInclude(name: name, flags: address.pointee.ifa_flags, includeVPNInterfaces: includeVPNInterfaces) else {
                continue
            }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            receivedBytes += UInt64(data.ifi_ibytes)
            sentBytes += UInt64(data.ifi_obytes)
            interfacesByName[name] = NetworkInterfaceMetric(id: name, name: name)
        }

        return NetworkCounterSample(
            timestamp: Date(),
            receivedBytes: receivedBytes,
            sentBytes: sentBytes,
            interfaces: interfacesByName.values.sorted { $0.name < $1.name }
        )
    }

    private static func shouldInclude(name: String, flags: UInt32, includeVPNInterfaces: Bool) -> Bool {
        guard flags & UInt32(IFF_UP) != 0 else {
            return false
        }
        if flags & UInt32(IFF_LOOPBACK) != 0 {
            return false
        }
        if name.hasPrefix("utun") {
            return includeVPNInterfaces
        }

        let excludedPrefixes = ["awdl", "llw", "bridge", "lo", "gif", "stf", "anpi"]
        guard !excludedPrefixes.contains(where: name.hasPrefix) else {
            return false
        }

        return name.hasPrefix("en")
    }
}

private extension UInt64 {
    func subtractingReportingWrap(_ previous: UInt64) -> UInt64 {
        self >= previous ? self - previous : 0
    }
}
