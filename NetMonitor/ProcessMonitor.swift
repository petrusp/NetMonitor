import Foundation

/// Represents network usage for a single process
struct ProcessNetworkUsage {
    let name: String
    let pid: Int
    var bytesIn: UInt64 = 0
    var bytesOut: UInt64 = 0
    var speedIn: Double = 0
    var speedOut: Double = 0
    var isActive: Bool = true  // false = grayed out, waiting to be removed
}

/// Monitors per-process network usage using nettop
class ProcessMonitor {

    private var previousStats: [Int: (name: String, bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var previousTimestamp: Date?

    /// How long to keep inactive processes visible (in seconds)
    private let fadeOutDuration: TimeInterval = 30.0

    /// Track when each process was last active (by PID)
    private var lastActiveTime: [Int: Date] = [:]

    /// Track last known usage for fading processes
    private var lastKnownUsage: [Int: ProcessNetworkUsage] = [:]

    /// Current process usage sorted by total speed (descending)
    private(set) var topProcesses: [ProcessNetworkUsage] = []

    /// Update process stats - call this on each timer tick
    func update() {
        let currentStats = readProcessStats()
        let currentTime = Date()

        guard let prevTime = previousTimestamp else {
            previousStats = currentStats
            previousTimestamp = currentTime
            return
        }

        let interval = currentTime.timeIntervalSince(prevTime)
        guard interval > 0 else { return }

        var activeProcesses: [Int: ProcessNetworkUsage] = [:]

        for (pid, current) in currentStats {
            var usage = ProcessNetworkUsage(
                name: current.name,
                pid: pid,
                bytesIn: current.bytesIn,
                bytesOut: current.bytesOut,
                isActive: true
            )

            if let previous = previousStats[pid] {
                let prevBytesIn = previous.bytesIn
                let prevBytesOut = previous.bytesOut
                let bytesInDiff = current.bytesIn >= prevBytesIn
                    ? current.bytesIn - prevBytesIn
                    : current.bytesIn
                let bytesOutDiff = current.bytesOut >= prevBytesOut
                    ? current.bytesOut - prevBytesOut
                    : current.bytesOut

                usage.speedIn = Double(bytesInDiff) / interval
                usage.speedOut = Double(bytesOutDiff) / interval
            }

            // Track active processes
            if usage.speedIn > 100 || usage.speedOut > 100 {
                activeProcesses[pid] = usage
                lastActiveTime[pid] = currentTime
                lastKnownUsage[pid] = usage
            }
        }

        // Build final list: active processes + recently inactive (grayed out)
        var allProcesses: [ProcessNetworkUsage] = Array(activeProcesses.values)

        // Add recently inactive processes (grayed out)
        for (pid, lastTime) in lastActiveTime {
            if activeProcesses[pid] == nil {
                // Process is no longer active
                let elapsed = currentTime.timeIntervalSince(lastTime)
                if elapsed < fadeOutDuration {
                    // Still within fade-out period - show grayed out with last known speeds
                    if var usage = lastKnownUsage[pid] {
                        usage.isActive = false
                        // Keep the last known speeds (don't zero them out)
                        allProcesses.append(usage)
                    }
                } else {
                    // Fade-out period expired - remove from tracking
                    lastKnownUsage.removeValue(forKey: pid)
                }
            }
        }

        // Clean up expired entries from lastActiveTime
        lastActiveTime = lastActiveTime.filter { pid, lastTime in
            currentTime.timeIntervalSince(lastTime) < fadeOutDuration || activeProcesses[pid] != nil
        }

        // Separate active and inactive
        let active = allProcesses.filter { $0.isActive }
            .sorted { ($0.speedIn + $0.speedOut) > ($1.speedIn + $1.speedOut) }
            .prefix(5)

        let inactive = allProcesses.filter { !$0.isActive }
            .prefix(3)  // Limit inactive to 3

        // Active first, then inactive
        topProcesses = Array(active) + Array(inactive)

        previousStats = currentStats
        previousTimestamp = currentTime
    }

    /// Read current per-process network stats using nettop
    private func readProcessStats() -> [Int: (name: String, bytesIn: UInt64, bytesOut: UInt64)] {
        var stats: [Int: (name: String, bytesIn: UInt64, bytesOut: UInt64)] = [:]

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-L", "1", "-x", "-J", "bytes_in,bytes_out"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                stats = parseNettopOutput(output)
            }
        } catch {
            // Silently fail - nettop might not be available
        }

        return stats
    }

    /// Parse nettop output to extract per-process stats
    private func parseNettopOutput(_ output: String) -> [Int: (name: String, bytesIn: UInt64, bytesOut: UInt64)] {
        var stats: [Int: (name: String, bytesIn: UInt64, bytesOut: UInt64)] = [:]
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            // Skip header and empty lines
            if line.isEmpty || line.contains("bytes_in") || line.hasPrefix("time") {
                continue
            }

            let components = line.components(separatedBy: ",")
            guard components.count >= 3 else { continue }

            // First component is "process.pid"
            let processInfo = components[0]
            let parts = processInfo.components(separatedBy: ".")

            guard parts.count >= 2,
                  let pid = Int(parts.last ?? "") else { continue }

            let name = parts.dropLast().joined(separator: ".")

            // Parse bytes_in and bytes_out
            let bytesIn = UInt64(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
            let bytesOut = UInt64(components[2].trimmingCharacters(in: .whitespaces)) ?? 0

            // Aggregate by PID (nettop can show multiple entries per process)
            if let existing = stats[pid] {
                stats[pid] = (name: name, bytesIn: existing.bytesIn + bytesIn, bytesOut: existing.bytesOut + bytesOut)
            } else {
                stats[pid] = (name: name, bytesIn: bytesIn, bytesOut: bytesOut)
            }
        }

        return stats
    }
}
