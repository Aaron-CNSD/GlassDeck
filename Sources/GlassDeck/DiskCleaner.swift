import Foundation

/// Disk cleaner: scan and purge caches, Xcode DerivedData, and temp files,
/// reporting how much space was freed.
enum DiskCleaner {

    struct CleanTarget {
        let name: String
        let path: String
        let isDirectory: Bool
    }

    /// All cleanable locations (user-level only — safe, no system dirs).
    static let targets: [CleanTarget] = [
        CleanTarget(name: "Xcode DerivedData",
                    path: "\(NSHomeDirectory())/Library/Developer/Xcode/DerivedData",
                    isDirectory: true),
        CleanTarget(name: "Xcode Archives",
                    path: "\(NSHomeDirectory())/Library/Developer/Xcode/Archives",
                    isDirectory: true),
        CleanTarget(name: "User Cache",
                    path: "\(NSHomeDirectory())/Library/Caches",
                    isDirectory: true),
        CleanTarget(name: "CocoaPods Cache",
                    path: "\(NSHomeDirectory())/Library/Caches/CocoaPods",
                    isDirectory: true),
        CleanTarget(name: "Homebrew Cache",
                    path: "\(NSHomeDirectory())/Library/Caches/Homebrew",
                    isDirectory: true),
        CleanTarget(name: "SwiftPM Cache",
                    path: "\(NSHomeDirectory())/Library/Caches/org.swift.swiftpm",
                    isDirectory: true),
    ]

    /// Recursively compute directory size in bytes.
    static func size(ofPath path: String) -> UInt64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        guard isDir.boolValue else {
            return (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? UInt64) ?? 0
        }
        var total: UInt64 = 0
        if let enumerator = FileManager.default.enumerator(atPath: path) {
            for case let file as String in enumerator {
                let full = (path as NSString).appendingPathComponent(file)
                var fileIsDir: ObjCBool = false
                FileManager.default.fileExists(atPath: full, isDirectory: &fileIsDir)
                if !fileIsDir.boolValue {
                    let s = (try? FileManager.default.attributesOfItem(atPath: full)[.size] as? UInt64) ?? 0
                    total += s
                }
            }
        }
        return total
    }

    /// Return sizes for all targets (name, bytes).
    static func scan() -> [(name: String, bytes: UInt64)] {
        return targets.map { ($0.name, size(ofPath: $0.path)) }
    }

    /// Delete the contents of a target and return freed bytes.
    @discardableResult
    static func clean(targetName: String) -> UInt64 {
        guard let target = targets.first(where: { $0.name == targetName }) else { return 0 }
        let before = size(ofPath: target.path)
        do {
            let fm = FileManager.default
            let contents = (try? fm.contentsOfDirectory(atPath: target.path)) ?? []
            for item in contents {
                let full = (target.path as NSString).appendingPathComponent(item)
                try? fm.removeItem(atPath: full)
            }
        }
        let after = size(ofPath: target.path)
        return before > after ? before - after : 0
    }

    /// Clean everything and return total freed bytes.
    static func cleanAll() -> UInt64 {
        return targets.reduce(0) { $0 + clean(targetName: $1.name) }
    }
}
