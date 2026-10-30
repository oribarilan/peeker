import Darwin
import Foundation

/// POC instrumentation, active when `PEEKER_BENCH_OUT` is set: the app opens its file argument
/// `PEEKER_BENCH_REPEAT` times in a `PEEKER_BENCH_MODE` ("window" or "panel"), appends one JSON line per open, and quits.
struct Bench {
    let output: URL
    let mode: String
    let repeats: Int

    static let current: Bench? = {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["PEEKER_BENCH_OUT"] else { return nil }
        return Bench(output: URL(filePath: path), mode: env["PEEKER_BENCH_MODE"] ?? "window", repeats: Int(env["PEEKER_BENCH_REPEAT"] ?? "") ?? 1)
    }()

    func record(_ row: [String: Any]) {
        guard var line = try? JSONSerialization.data(withJSONObject: row, options: .sortedKeys) else { return }
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: output) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: output)
        }
    }

    static func ms(_ duration: Duration) -> Double {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        return (seconds * 10_000).rounded() / 10
    }

    static func msSinceProcessStart() -> Double {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return -1 }
        let started = info.kp_proc.p_un.__p_starttime
        let start = Double(started.tv_sec) + Double(started.tv_usec) / 1e6
        return ((Date().timeIntervalSince1970 - start) * 10_000).rounded() / 10
    }

    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task_self_trap(), task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? (Double(info.phys_footprint) / 1_048_576 * 10).rounded() / 10 : -1
    }
}
