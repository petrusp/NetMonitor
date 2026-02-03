import Foundation

/// Utility for formatting byte counts and network speeds into human-readable strings
struct ByteFormatter {

    /// Format bytes into human-readable size (e.g., "1.24 GB")
    static func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else {
            return String(format: "%.2f %@", value, units[unitIndex])
        }
    }

    /// Format bytes per second into speed string (e.g., "1.2 MB/s")
    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else if value >= 100 {
            return String(format: "%.0f %@", value, units[unitIndex])
        } else if value >= 10 {
            return String(format: "%.1f %@", value, units[unitIndex])
        } else {
            return String(format: "%.2f %@", value, units[unitIndex])
        }
    }

    /// Format bytes per second into fixed-width speed string for status bar (right-aligned)
    /// Uses KB/s as minimum unit to maintain consistent width
    static func formatSpeedFixedWidth(_ bytesPerSecond: Double, width: Int = 9) -> String {
        let units = ["KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond / 1024  // Start at KB/s
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        let speed: String
        if value < 0.01 {
            speed = "0 KB/s"
        } else if value >= 100 {
            speed = String(format: "%.0f %@", value, units[unitIndex])
        } else if value >= 10 {
            speed = String(format: "%.1f %@", value, units[unitIndex])
        } else {
            speed = String(format: "%.2f %@", value, units[unitIndex])
        }

        if speed.count < width {
            return String(repeating: " ", count: width - speed.count) + speed
        }
        return speed
    }

    /// Format duration in seconds to human-readable (e.g., "2h 15m")
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}
