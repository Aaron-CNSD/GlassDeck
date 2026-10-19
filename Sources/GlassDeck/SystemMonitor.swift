import Foundation
import Darwin

/// Live system metrics: CPU, memory, and network throughput.
/// Uses only public APIs (host_statistics64, sysctl, getifaddrs).
enum SystemMonitor {

    // MARK: - CPU

    private static var lastCPU: host_cpu_load_info?

    /// CPU usage as a 0.0...1.0 fraction (system-wide, since last call).
    static var cpuUsage: Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)
        let total = user + system + idle + nice

        var usage: Double = 0
        if let last = lastCPU {
            let lastUser = Double(last.cpu_ticks.0)
            let lastSystem = Double(last.cpu_ticks.1)
            let lastIdle = Double(last.cpu_ticks.2)
            let lastNice = Double(last.cpu_ticks.3)
            let lastTotal = lastUser + lastSystem + lastIdle + lastNice

            let dTotal = total - lastTotal
            let dIdle = idle - lastIdle
            if dTotal > 0 {
                usage = max(0, min(1, (dTotal - dIdle) / dTotal))
            }
        }
        lastCPU = info
        return usage
    }

    // MARK: - Memory

    /// Used memory in bytes.
    static var usedMemory: UInt64 {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        return active + inactive + wired + compressed
    }

    /// Total physical memory in bytes.
    static var totalMemory: UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &value, &size, nil, 0)
        return value
    }

    // MARK: - Network

    private static var lastRx: UInt64 = 0
    private static var lastTx: UInt64 = 0
    private static var lastTime: TimeInterval = 0

    /// Current download/upload throughput in bytes/second.
    static func networkThroughput() -> (rx: Double, tx: Double) {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return (0, 0)
        }
        defer { freeifaddrs(ifaddrPtr) }

        var totalRx: UInt64 = 0
        var totalTx: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while ptr != nil {
            if let addr = ptr?.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ptr!.pointee.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("pdp") {
                    let data = ptr!.pointee.ifa_data
                    if let data = data {
                        let networkData = data.assumingMemoryBound(to: if_data.self)
                        totalRx += UInt64(networkData.pointee.ifi_ibytes)
                        totalTx += UInt64(networkData.pointee.ifi_obytes)
                    }
                }
            }
            ptr = ptr?.pointee.ifa_next
        }

        let now = Date().timeIntervalSince1970
        var rxRate: Double = 0
        var txRate: Double = 0
        if lastTime > 0 {
            let dt = now - lastTime
            if dt > 0 {
                rxRate = Double(totalRx &- lastRx) / dt
                txRate = Double(totalTx &- lastTx) / dt
            }
        }
        lastRx = totalRx
        lastTx = totalTx
        lastTime = now
        return (rxRate, txRate)
    }
}

/// Byte formatting helpers.
enum ByteFormatter {
    static func string(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1024 { return "\(Int(b)) B" }
        if b < 1024 * 1024 { return String(format: "%.1f KB", b / 1024) }
        if b < 1024 * 1024 * 1024 { return String(format: "%.1f MB", b / 1024 / 1024) }
        return String(format: "%.2f GB", b / 1024 / 1024 / 1024)
    }

    static func rate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 { return String(format: "%.0f B/s", bytesPerSec) }
        if bytesPerSec < 1024 * 1024 { return String(format: "%.1f KB/s", bytesPerSec / 1024) }
        return String(format: "%.1f MB/s", bytesPerSec / 1024 / 1024)
    }
}
