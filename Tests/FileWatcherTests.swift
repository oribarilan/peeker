import Foundation
import Testing

@Suite(.serialized) struct FileWatcherTests {
    @Test func firesOnWrite() async throws {
        let file = try TempFile.make(Data("a".utf8))
        var count = 0
        let watcher = FileWatcher(url: file) { count += 1 }
        defer { watcher.stop() }
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("b".utf8))
        try handle.close()
        try await waitUntil(seconds: 2) { count == 1 }
    }

    @Test func keepsWatchingAfterAtomicReplace() async throws {
        let file = try TempFile.make(Data("a".utf8))
        var count = 0
        let watcher = FileWatcher(url: file) { count += 1 }
        defer { watcher.stop() }
        try Data("b".utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 2) { count == 1 }
        try Data("c".utf8).write(to: file, options: .atomic)
        try await waitUntil(seconds: 2) { count == 2 }
    }

    /// Past the 1 s reopen retry the watcher keeps checking slowly, so a file that comes back is picked up.
    @Test func picksUpAFileRecreatedLater() async throws {
        let file = try TempFile.make(Data("a".utf8))
        var count = 0
        let watcher = FileWatcher(url: file) { count += 1 }
        defer { watcher.stop() }
        try FileManager.default.removeItem(at: file)
        try await Task.sleep(for: .milliseconds(1500))
        try Data("b".utf8).write(to: file)
        try await waitUntil(seconds: 4) { count == 1 }
    }

    @Test func stopEndsTheSlowRetries() async throws {
        let file = try TempFile.make(Data("a".utf8))
        var count = 0
        let watcher = FileWatcher(url: file) { count += 1 }
        try FileManager.default.removeItem(at: file)
        try await Task.sleep(for: .milliseconds(1500))
        watcher.stop()
        try Data("b".utf8).write(to: file)
        try await Task.sleep(for: .milliseconds(3000))
        #expect(count == 0)
    }

    @Test func stopEndsTheCallbacks() async throws {
        let file = try TempFile.make(Data("a".utf8))
        var count = 0
        let watcher = FileWatcher(url: file) { count += 1 }
        watcher.stop()
        try Data("b".utf8).write(to: file)
        try await Task.sleep(for: .milliseconds(500))
        #expect(count == 0)
    }
}
