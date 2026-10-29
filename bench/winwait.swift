// Launches an app on a file through LaunchServices and prints milliseconds until its first
// on-screen document window exists. Same method for every app, so comparisons are fair.
// Window visibility is not the same as content painted; Preview++ also logs that (PPP_BENCH_OUT).
//
// usage: winwait <process-name> <app-path> <file> [timeout-seconds]
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write(Data("usage: winwait <process-name> <app-path> <file> [timeout]\n".utf8))
    exit(2)
}
let (name, app, file) = (args[1], args[2], args[3])
let timeout = args.count > 4 ? Double(args[4]) ?? 60 : 60

func documentWindowVisible() -> Bool {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.contains { window in
        guard window[kCGWindowOwnerName as String] as? String == name,
              window[kCGWindowLayer as String] as? Int == 0,
              let bounds = window[kCGWindowBounds as String] as? [String: Double] else { return false }
        return (bounds["Height"] ?? 0) > 200 && (bounds["Width"] ?? 0) > 200
    }
}

let start = DispatchTime.now()
let open = Process()
open.executableURL = URL(filePath: "/usr/bin/open")
open.arguments = ["-F", "-a", app, file]
try open.run()
while !documentWindowVisible() {
    if Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e9 > timeout {
        print("timeout")
        exit(1)
    }
    usleep(1000)
}
print(String(format: "%.1f", Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e6))
