import Foundation
import Darwin

/// Represents network statistics for a single interface
struct InterfaceStats {
    let name: String
    let bytesIn: UInt64
    let bytesOut: UInt64
    var speedIn: Double = 0  // bytes per second
    var speedOut: Double = 0 // bytes per second

    /// Human-readable interface name
    var displayName: String {
        switch name {
        case "en0": return "en0 (Wi-Fi)"
        case "en1": return "en1 (Ethernet)"
        case "lo0": return "lo0 (Loopback)"
        default: return name
        }
    }
}

/// Monitors network traffic across all interfaces
class NetworkMonitor {

    /// Current per-interface statistics with speeds
    private(set) var interfaceStats: [String: InterfaceStats] = [:]

    /// Previous reading for calculating speeds
    private var previousStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var previousTimestamp: Date?

    /// Session tracking
    private(set) var sessionStartTime: Date
    private var initialStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]

    /// Total session bytes
    var sessionBytesIn: UInt64 {
        var total: UInt64 = 0
        for (name, stats) in interfaceStats {
            if name == "lo0" { continue }
            if let initial = initialStats[name] {
                if stats.bytesIn >= initial.bytesIn {
                    total += stats.bytesIn - initial.bytesIn
                }
            }
        }
        return total
    }

    var sessionBytesOut: UInt64 {
        var total: UInt64 = 0
        for (name, stats) in interfaceStats {
            if name == "lo0" { continue }
            if let initial = initialStats[name] {
                if stats.bytesOut >= initial.bytesOut {
                    total += stats.bytesOut - initial.bytesOut
                }
            }
        }
        return total
    }

    /// Total current speeds (excluding loopback)
    var totalSpeedIn: Double {
        interfaceStats.values
            .filter { $0.name != "lo0" }
            .reduce(0) { $0 + $1.speedIn }
    }

    var totalSpeedOut: Double {
        interfaceStats.values
            .filter { $0.name != "lo0" }
            .reduce(0) { $0 + $1.speedOut }
    }

    /// Session duration
    var sessionDuration: TimeInterval {
        Date().timeIntervalSince(sessionStartTime)
    }

    init() {
        sessionStartTime = Date()
        // Initial read to establish baseline
        let stats = readNetworkStats()
        initialStats = stats
        previousStats = stats
        previousTimestamp = Date()

        // Initialize interface stats
        for (name, data) in stats {
            interfaceStats[name] = InterfaceStats(
                name: name,
                bytesIn: data.bytesIn,
                bytesOut: data.bytesOut
            )
        }
    }

    /// Update stats and calculate speeds - call this on each timer tick
    func update() {
        let currentStats = readNetworkStats()
        let currentTime = Date()

        guard let prevTime = previousTimestamp else {
            previousStats = currentStats
            previousTimestamp = currentTime
            return
        }

        let interval = currentTime.timeIntervalSince(prevTime)
        guard interval > 0 else { return }

        for (name, current) in currentStats {
            var stats = InterfaceStats(
                name: name,
                bytesIn: current.bytesIn,
                bytesOut: current.bytesOut
            )

            // Track new interfaces that appear after app start
            if initialStats[name] == nil {
                initialStats[name] = current
            }

            if let previous = previousStats[name] {
                // Handle counter overflow/reset
                let bytesInDiff = current.bytesIn >= previous.bytesIn
                    ? current.bytesIn - previous.bytesIn
                    : current.bytesIn
                let bytesOutDiff = current.bytesOut >= previous.bytesOut
                    ? current.bytesOut - previous.bytesOut
                    : current.bytesOut

                stats.speedIn = Double(bytesInDiff) / interval
                stats.speedOut = Double(bytesOutDiff) / interval
            }

            interfaceStats[name] = stats
        }

        previousStats = currentStats
        previousTimestamp = currentTime
    }

    /// Read current network statistics from all interfaces using getifaddrs
    private func readNetworkStats() -> [String: (bytesIn: UInt64, bytesOut: UInt64)] {
        var stats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return stats }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let name = String(cString: interface.ifa_name)

            // Check if this is a link-level address (contains interface stats)
            if let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = interface.ifa_data {
                    let ifData = data.assumingMemoryBound(to: if_data.self)
                    stats[name] = (
                        bytesIn: UInt64(ifData.pointee.ifi_ibytes),
                        bytesOut: UInt64(ifData.pointee.ifi_obytes)
                    )
                }
            }
            ptr = interface.ifa_next
        }

        return stats
    }

    /// Get active interfaces (excluding loopback, sorted by name)
    var activeInterfaces: [InterfaceStats] {
        interfaceStats.values
            .filter { $0.name != "lo0" }
            .sorted { $0.name < $1.name }
    }
}
