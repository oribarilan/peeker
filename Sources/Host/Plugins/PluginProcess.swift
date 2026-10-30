import Darwin
import Foundation
import os

enum PluginTimeout {
    static let open = Duration.seconds(10), command = Duration.seconds(10), save = Duration.seconds(30)
}

/// One plugin's process: started on the first request, shared by every open document of that plugin,
/// stopped after `idleSeconds` with no documents open, and restarted on demand after a crash.
///
/// Every request is answered exactly once: by the plugin's reply, or with a failure when the plugin crashes, misses
/// the request's deadline (it is then killed), or sends a line that isn't a `Response` (also killed).
final class PluginProcess {
    typealias OnReply = (Result<Reply, PluginFailure>) -> Void

    private struct Pending {
        let onReply: OnReply
        let deadline: Task<Void, Never>
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "plugins")
    let entry: PluginEntry
    private let idleSeconds: TimeInterval
    private var process: Process?
    private var stdin: Pipe?
    private var nextID = 1
    private var pending: [Int: Pending] = [:]
    private var documents: [DocumentID: (String) -> Void] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
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
    func attach(_ doc: DocumentID, onCrash: @escaping (String) -> Void) {
        documents[doc] = onCrash
        idleTimer?.invalidate()
    }

    func detach(_ doc: DocumentID) {
        documents.removeValue(forKey: doc)
        scheduleIdleExitIfUnused()
    }

    func request(_ call: Call, doc: DocumentID, timeout: Duration) async throws(PluginFailure) -> Reply {
        try await withCheckedContinuation { continuation in
            send(call, doc: doc, timeout: timeout) { continuation.resume(returning: $0) }
        }.get()
    }

    /// Like `request`, but `onReply` runs as soon as the reply is read. Resuming an awaiting task takes another
    /// main-actor turn, which at launch lands after a display pass and cost first paint about 10 ms.
    func send(_ call: Call, doc: DocumentID, timeout: Duration, onReply: @escaping OnReply) {
        do {
            try startIfNeeded()
        } catch {
            onReply(.failure(PluginFailure("Couldn't start the \(entry.manifest.name) plugin: \(error.localizedDescription)")))
            return
        }
        let id = nextID
        nextID += 1
        // Holds `self` until the request is answered, so every request gets an answer even if nothing else keeps this alive.
        let deadline = Task {
            do { try await Task.sleep(for: timeout) } catch { return }  // cancelled: answered in time
            guard pending[id] != nil else { return }
            killProcess(because: "The \(entry.manifest.name) plugin didn't respond within \(timeout.components.seconds) seconds and was stopped. The rest of the app is unaffected.")
        }
        pending[id] = Pending(onReply: onReply, deadline: deadline)
        if !write(Request(id: id, doc: doc, call: call)) {
            answer(id, .failure(PluginFailure("The \(entry.manifest.name) plugin isn't responding.")))
        }
    }

    /// Tells the plugin a document closed. No reply; never starts the process.
    func notifyClose(_ doc: DocumentID) {
        guard isRunning else { return }
        _ = write(Request(id: 0, doc: doc, call: .close))
    }

    private func startIfNeeded() throws {
        if let old = process, !old.isRunning {
            // It died, but its termination handler hasn't reached the main actor yet.
            exited(status: old.terminationStatus, reason: old.terminationReason)
        }
        guard process == nil else { return }
        let process = Process()
        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        process.executableURL = entry.executable
        // The user is waiting on this reply; without it the plugin may start on efficiency cores.
        process.qualityOfService = .userInteractive
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        let replies = LineBuffer(), errors = LineBuffer()
        stdout.fileHandleForReading.readabilityHandler = { [weak self, weak process] handle in
            let data = Self.read(handle)
            Task { @MainActor in
                guard let self, let process, self.process === process else { return }
                self.consume(replies.append(data))
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { [id = entry.id] handle in
            let data = Self.read(handle)
            Task { @MainActor in
                let lines = data.isEmpty ? [errors.rest()] : errors.append(data)
                for line in lines where !line.isEmpty {
                    Self.log.info("\(id, privacy: .public): \(String(decoding: line, as: UTF8.self), privacy: .public)")
                }
            }
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
    }

    /// Reads what's available. At end of file the handler would keep firing with empty data, spinning a core.
    private nonisolated static func read(_ handle: FileHandle) -> Data {
        let data = handle.availableData
        if data.isEmpty { handle.readabilityHandler = nil }
        return data
    }

    private func write(_ request: Request) -> Bool {
        guard let stdin else { return false }
        do {
            var line = try encoder.encode(request)
            line.append(0x0A)
            try stdin.fileHandleForWriting.write(contentsOf: line)
            return true
        } catch {
            Self.log.error("\(self.entry.id, privacy: .public): couldn't send request: \(error, privacy: .public)")
            return false
        }
    }

    private func consume(_ lines: [Data]) {
        let source = process
        // A callback may have replaced the process; the rest of the lines came from the old one.
        for line in lines where process === source {
            let response: Response
            do {
                response = try decoder.decode(Response.self, from: line)
            } catch {
                Self.log.error("\(self.entry.id, privacy: .public): unreadable reply: \(error, privacy: .public)")
                killProcess(because: "The \(entry.manifest.name) plugin sent a reply the app couldn't read and was stopped. The rest of the app is unaffected.")
                return
            }
            switch response.outcome {
            case .reply(let reply):
                if pending[response.id] == nil { reply.view?.sharedFile.map(SharedFile.discard) }
                answer(response.id, .success(reply))
            case .failure(let failure):
                answer(response.id, .failure(failure))
            }
        }
    }

    private func answer(_ id: Int, _ result: Result<Reply, PluginFailure>) {
        guard let request = pending.removeValue(forKey: id) else { return }
        request.deadline.cancel()
        request.onReply(result)
    }

    /// SIGKILLs the process and fails everything waiting on it with `message`.
    private func killProcess(because message: String) {
        guard let process else { return }
        // Once it has exited its pid may already belong to another process.
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        stopped(message: message)
    }

    private func exited(status: Int32, reason: Process.TerminationReason) {
        stopped(message: "The \(entry.manifest.name) plugin stopped (\(reason == .uncaughtSignal ? "signal" : "status") \(status)). The rest of the app is unaffected.")
    }

    /// Forgets the current process, then fails its pending requests and tells attached documents. Callbacks may start
    /// a new process and request; the table is emptied first so their entries survive.
    private func stopped(message: String) {
        process = nil
        stdin = nil
        let failed = pending
        pending.removeAll()
        for request in failed.values {
            request.deadline.cancel()
            request.onReply(.failure(PluginFailure(message)))
        }
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
        retire()
    }

    /// Benchmark only: ends the process now and waits for it, so the next request pays a fresh start.
    func stopAndWait() {
        guard let process, isRunning else { return }
        idleTimer?.invalidate()
        idleTimer = nil
        retire()
        process.waitUntilExit()
    }

    /// Closes stdin, which ends the plugin's read loop so it exits on its own, and forgets the process: the next
    /// request starts a new one, and this one's exit is no crash.
    private func retire() {
        do {
            try stdin?.fileHandleForWriting.close()
        } catch {
            Self.log.error("\(self.entry.id, privacy: .public): couldn't close stdin: \(error, privacy: .public)")
        }
        process = nil
        stdin = nil
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

/// Splits a byte stream into newline-terminated lines.
private final class LineBuffer {
    private var data = Data()

    /// The complete lines `chunk` finishes, without their newlines.
    func append(_ chunk: Data) -> [Data] {
        // Replies can be megabytes; only scan the bytes that just arrived for the line break.
        var searchFrom = data.count
        data.append(chunk)
        var lines: [Data] = []
        while let newline = newline(from: searchFrom) {
            lines.append(data[data.startIndex..<newline])
            data.removeSubrange(data.startIndex...newline)
            searchFrom = 0
        }
        return lines
    }

    /// An unterminated last line, at end of file.
    func rest() -> Data {
        defer { data.removeAll() }
        return data
    }

    private func newline(from offset: Int) -> Data.Index? {
        guard offset < data.count else { return nil }
        return data.withUnsafeBytes { bytes -> Data.Index? in
            guard let base = bytes.baseAddress, let hit = memchr(base + offset, 0x0A, bytes.count - offset) else { return nil }
            return data.startIndex + (UnsafeRawPointer(hit) - base)
        }
    }
}

extension View {
    /// The shared file this view hands over, which the host must unlink if it never maps it.
    var sharedFile: SharedFileRef? {
        switch self {
        case .bitmap(let bitmap): bitmap.file
        case .text(let text): text.file
        case .markdown, .pdf: nil
        }
    }
}
