import Darwin
import Foundation

/// One plugin's process: started on the first request, shared by every open document of that plugin,
/// stopped after `idleSeconds` with no documents open, and restarted on demand after a crash.
final class PluginProcess {
    struct Failure: Error {
        let message: String
    }

    typealias Reply = (Result<[String: Any], Failure>) -> Void

    let entry: PluginEntry
    private let idleSeconds: TimeInterval
    private var process: Process?
    private var stdin: Pipe?
    private var buffer = Data()
    private var nextID = 1
    private var pending: [Int: Reply] = [:]
    private var documents: [String: (String) -> Void] = [:]
    private var idleTimer: Timer?
    /// How long the last `Process.run()` took, for the benchmark.
    private(set) var lastLaunch: Duration = .zero

    init(entry: PluginEntry, idleSeconds: TimeInterval) {
        self.entry = entry
        self.idleSeconds = idleSeconds
    }

    var isRunning: Bool { process?.isRunning == true }
    var pid: pid_t? { isRunning ? process?.processIdentifier : nil }

    /// Registers an open document; `onCrash` runs if the process dies while it is open.
    func attach(_ doc: String, onCrash: @escaping (String) -> Void) {
        documents[doc] = onCrash
        idleTimer?.invalidate()
    }

    func detach(_ doc: String) {
        documents.removeValue(forKey: doc)
        scheduleIdleExitIfUnused()
    }

    func request(_ method: String, _ params: [String: Any], reply: @escaping Reply) {
        do {
            try startIfNeeded()
        } catch {
            reply(.failure(Failure(message: "Couldn't start the \(entry.manifest.name) plugin: \(error.localizedDescription)")))
            return
        }
        let id = nextID
        nextID += 1
        pending[id] = reply
        if !send(["id": id, "method": method, "params": params]) {
            pending.removeValue(forKey: id)?(.failure(Failure(message: "The \(entry.manifest.name) plugin isn't responding.")))
        }
    }

    /// A message with no reply, e.g. "close". Never starts the process.
    func notify(_ method: String, _ params: [String: Any]) {
        guard isRunning else { return }
        _ = send(["method": method, "params": params])
    }

    private func startIfNeeded() throws {
        guard !isRunning else { return }
        let process = Process()
        let stdin = Pipe(), stdout = Pipe()
        process.executableURL = entry.executable
        // The user is waiting on this reply; without it the plugin may start on efficiency cores.
        process.qualityOfService = .userInteractive
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.standardError
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            // At end of file the handler would keep firing with empty data, spinning a core.
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            Task { @MainActor in self?.consume(data) }
        }
        process.terminationHandler = { [weak self, weak process] finished in
            let status = finished.terminationStatus
            let reason = finished.terminationReason
            Task { @MainActor in
                guard let self, let process, self.process === process else { return }
                self.exited(status: status, reason: reason)
            }
        }
        let started = ContinuousClock.now
        try process.run()
        lastLaunch = .now - started
        self.process = process
        self.stdin = stdin
        buffer.removeAll()
    }

    private func send(_ message: [String: Any]) -> Bool {
        guard var line = try? JSONSerialization.data(withJSONObject: message), let stdin else { return false }
        line.append(0x0A)
        do {
            try stdin.fileHandleForWriting.write(contentsOf: line)
            return true
        } catch {
            return false
        }
    }

    private func consume(_ data: Data) {
        // Replies can be megabytes; only scan the bytes that just arrived for the line break.
        var searchFrom = buffer.count
        buffer.append(data)
        while let newline = Self.newline(in: buffer, from: searchFrom) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            searchFrom = 0
            guard let message = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                  let id = message["id"] as? Int, let reply = pending.removeValue(forKey: id) else { continue }
            if let result = message["result"] as? [String: Any] {
                reply(.success(result))
            } else {
                reply(.failure(Failure(message: message["error"] as? String ?? "The plugin sent a malformed reply.")))
            }
        }
    }

    private static func newline(in data: Data, from offset: Int) -> Data.Index? {
        guard offset < data.count else { return nil }
        return data.withUnsafeBytes { bytes -> Data.Index? in
            guard let base = bytes.baseAddress, let hit = memchr(base + offset, 0x0A, bytes.count - offset) else { return nil }
            return data.startIndex + (UnsafeRawPointer(hit) - base)
        }
    }

    private func exited(status: Int32, reason: Process.TerminationReason) {
        let stoppedForIdle = idleTimer == nil && documents.isEmpty && pending.isEmpty
        process = nil
        stdin = nil
        let message = "The \(entry.manifest.name) plugin stopped (\(reason == .uncaughtSignal ? "signal" : "status") \(status)). The rest of the app is unaffected."
        for reply in pending.values { reply(.failure(Failure(message: message))) }
        pending.removeAll()
        guard !stoppedForIdle else { return }
        for onCrash in documents.values { onCrash(message) }
    }

    private func scheduleIdleExitIfUnused() {
        idleTimer?.invalidate()
        guard documents.isEmpty, isRunning else { return }
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleSeconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopForIdle() }
        }
    }

    private func stopForIdle() {
        idleTimer = nil
        guard documents.isEmpty, pending.isEmpty else { return }
        // Closing stdin ends the plugin's read loop; it exits on its own.
        try? stdin?.fileHandleForWriting.close()
    }

    /// Benchmark only: ends the process now and waits for it, so the next request pays a fresh start.
    func stopAndWait() {
        guard let process, isRunning else { return }
        idleTimer?.invalidate()
        idleTimer = nil
        try? stdin?.fileHandleForWriting.close()
        process.waitUntilExit()
    }

    /// Physical memory of the plugin process, for the benchmark.
    var footprintMB: Double? {
        guard let pid else { return nil }
        var info = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
        }
        return result == 0 ? Double(info.ri_phys_footprint) / 1_048_576 : nil
    }
}
