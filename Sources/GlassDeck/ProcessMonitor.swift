import AppKit

/// One row in the "who is eating the CPU right now" list.
struct ProcessSample {
    let pid: pid_t
    let name: String
    /// Percent of one core, as reported by `ps`. Can exceed 100 on multicore work.
    let cpu: Double
    /// Resident memory in bytes.
    let memory: UInt64
}

/// Samples per-process CPU and memory.
///
/// Reads `ps` output on a utility queue: no entitlements, no Accessibility,
/// no private APIs. Only numbers are read, so this behaves identically for
/// processes owned by other users — quitting one of those simply fails and
/// reports back, it never half-succeeds.
enum ProcessMonitor {

    private static let queue = DispatchQueue(label: "com.glassdeck.processmonitor",
                                             qos: .utility)

    /// Fetches the busiest processes, newest numbers first, on the main queue.
    static func sample(limit: Int = 4, completion: @escaping ([ProcessSample]) -> Void) {
        queue.async {
            let samples = readTop(limit: limit)
            DispatchQueue.main.async { completion(samples) }
        }
    }

    /// Synchronous read. Exposed for tests and the offscreen layout harness.
    static func readTop(limit: Int) -> [ProcessSample] {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        // -r sorts by current CPU usage, so the first N lines are the answer.
        ps.arguments = ["-Ao", "pid=,pcpu=,rss=,comm=", "-r"]
        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = FileHandle.nullDevice
        do {
            try ps.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        // Never list ourselves: a menu bar panel claiming to be the busiest
        // process on the machine is not useful information.
        return parse(text, limit: limit,
                     excluding: [ProcessInfo.processInfo.processIdentifier])
    }

    /// Splits `pid pcpu rss comm` lines. Kept separate so it can be unit-tested
    /// without spawning anything.
    static func parse(_ text: String, limit: Int,
                      excluding excluded: Set<pid_t> = []) -> [ProcessSample] {
        var out: [ProcessSample] = []
        for line in text.split(separator: "\n") {
            // comm is a path and can contain spaces, so stop splitting at three.
            let parts = line.split(separator: " ", maxSplits: 3,
                                   omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = pid_t(parts[0]),
                  let cpu = Double(parts[1]),
                  let rssKB = UInt64(parts[2]) else { continue }
            if excluded.contains(pid) { continue }
            let name = displayName(for: String(parts[3]))
            // kernel_task is always near the top on macOS and cannot be quit.
            if name == "kernel_task" || name.isEmpty { continue }
            out.append(ProcessSample(pid: pid, name: name,
                                     cpu: cpu, memory: rssKB * 1024))
            if out.count >= limit { break }
        }
        return out
    }

    /// `"/Applications/Foo.app/Contents/MacOS/Foo"` → `"Foo"`.
    static func displayName(for path: String) -> String {
        if let range = path.range(of: ".app/") {
            let bundle = String(path[path.startIndex..<range.lowerBound])
            return (bundle as NSString).lastPathComponent
        }
        return (path as NSString).lastPathComponent
    }

    /// Asks a process to quit. GUI apps get a normal terminate request so they
    /// can save; everything else gets SIGTERM. Returns false if the process is
    /// gone or belongs to another user.
    static func quit(pid: pid_t) -> Bool {
        if let app = NSRunningApplication(processIdentifier: pid) {
            return app.terminate()
        }
        return kill(pid, SIGTERM) == 0
    }
}
