import Foundation
import os

/// Calls `onChange` on the main queue when the file at `url` is written to or replaced, coalescing changes over
/// 200 ms. An atomic save replaces the file, so after a delete or rename it reopens the path, retrying for up to 1 s
/// and then every 2 s, so a file that comes back later is picked up too. Call `stop()` when done.
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var changePending = false
    private var isStopped = false
    private static let coalescing = 0.2, retryInterval = 0.05, retries = 20, slowRetryInterval = 2.0
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.previewpp", category: "documents")

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        watch(attempt: 0, isReplacement: false)
    }

    func stop() {
        isStopped = true
        source?.cancel()
        source = nil
    }

    private func watch(attempt: Int, isReplacement: Bool) {
        guard !isStopped else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            let code = errno
            if attempt == Self.retries {
                Self.log.info("\(self.url.path, privacy: .private) is gone: \(String(cString: strerror(code)), privacy: .public); checking every 2 s")
            }
            let delay = attempt < Self.retries ? Self.retryInterval : Self.slowRetryInterval
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.watch(attempt: attempt + 1, isReplacement: isReplacement)
            }
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.handleEvent() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
        if isReplacement { scheduleChange() }
    }

    private func handleEvent() {
        guard let source, !isStopped else { return }
        if !source.data.isDisjoint(with: [.delete, .rename]) {
            source.cancel()
            self.source = nil
            watch(attempt: 0, isReplacement: true)
        } else {
            scheduleChange()
        }
    }

    private func scheduleChange() {
        guard !changePending else { return }
        changePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.coalescing) { [weak self] in
            guard let self else { return }
            changePending = false
            if !isStopped { onChange() }
        }
    }
}
