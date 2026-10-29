import Darwin
import Foundation

/// POC instrumentation. When `PPP_BENCH_OUT` is set, the first ready document appends one JSON line there and the app quits.
enum Bench {
    private(set) static var mainStarted = Date()
    static var discovery: Duration = .zero

    static var outputURL: URL? {
        ProcessInfo.processInfo.environment["PPP_BENCH_OUT"].map { URL(filePath: $0) }
    }

    static func markMain() {
        mainStarted = Date()
    }

    static var commandToRun: String? { ProcessInfo.processInfo.environment["PPP_BENCH_COMMAND"] }

    static func record(plugin: String, runtime: String, file: URL, open: Duration, failure: String? = nil, note: String? = nil) {
        guard let outputURL else { return }
        let now = Date()
        let start = processStart()
        var row: [String: Any] = [
            "plugin": plugin,
            "runtime": runtime,
            "file": file.lastPathComponent,
            "processToReadyMs": ms(now.timeIntervalSince(start)),
            "processToMainMs": ms(mainStarted.timeIntervalSince(start)),
            "discoveryMs": ms(discovery),
            "openToReadyMs": ms(open),
            "footprintMB": (footprintMB() * 10).rounded() / 10,
        ]
        if let failure { row["failure"] = failure }
        if let note { row["note"] = note }
        if var line = try? JSONSerialization.data(withJSONObject: row, options: .sortedKeys) {
            line.append(0x0A)
            if let handle = try? FileHandle(forWritingTo: outputURL) {
                handle.seekToEndOfFile()
                handle.write(line)
                try? handle.close()
            } else {
                try? line.write(to: outputURL)
            }
        }
    }

    private static func ms(_ seconds: TimeInterval) -> Double { (seconds * 10_000).rounded() / 10 }
    private static func ms(_ duration: Duration) -> Double {
        ms(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18)
    }

    private static func processStart() -> Date {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return mainStarted }
        let started = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: Double(started.tv_sec) + Double(started.tv_usec) / 1e6)
    }

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task_self_trap(), task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }
}
