import Foundation

/// A file in the temporary directory that carries bytes between processes.
nonisolated struct SharedFileRef: Codable, Sendable, Equatable {
    let path: String
    let byteCount: Int
}

nonisolated enum SharedFile {
    static let prefix = "peeker-shared-"
    static let maxBytes = 1 << 32

    /// Creates a file of `byteCount` bytes, lets `fill` write into it, and leaves the name for the receiver to unlink.
    static func create(byteCount: Int, fill: (UnsafeMutableRawBufferPointer) throws -> Void) throws(PluginFailure) -> SharedFileRef {
        guard (0...maxBytes).contains(byteCount) else { throw PluginFailure("shared file size out of range") }
        let path = FileManager.default.temporaryDirectory.appending(path: prefix + UUID().uuidString).path
        let fd = Darwin.open(path, O_CREAT | O_EXCL | O_RDWR, 0o600)
        guard fd >= 0 else { throw PluginFailure("could not create shared file") }
        defer { Darwin.close(fd) }
        guard ftruncate(fd, off_t(byteCount)) == 0 else {
            unlink(path)
            throw PluginFailure("could not size shared file")
        }
        if byteCount > 0 {
            guard let memory = mmap(nil, byteCount, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0), memory != MAP_FAILED else {
                unlink(path)
                throw PluginFailure("could not map shared file")
            }
            defer { munmap(memory, byteCount) }
            do {
                try fill(UnsafeMutableRawBufferPointer(start: memory, count: byteCount))
            } catch {
                unlink(path)
                throw error as? PluginFailure ?? PluginFailure(error.localizedDescription)
            }
        }
        return SharedFileRef(path: path, byteCount: byteCount)
    }

    static func create(_ data: Data) throws(PluginFailure) -> SharedFileRef {
        try create(byteCount: data.count) { buffer in _ = data.copyBytes(to: buffer) }
    }

    /// Maps the file, passes its bytes to `read`, then unmaps it. The bytes are valid only inside `read`;
    /// copy out what you need. Prefer this to `map`, whose bytes die with the `MappedFile`.
    static func withMapped<Result>(_ ref: SharedFileRef, _ read: (UnsafeRawBufferPointer) -> Result) throws(PluginFailure) -> Result {
        let mapped = try map(ref)
        return withExtendedLifetime(mapped) { read(mapped.bytes) }
    }

    /// Maps a file a plugin named, after checking that its numbers can't make the reader go out of bounds,
    /// then unlinks the name; the mapping outlives it. For a one-off read use `withMapped`.
    static func map(_ ref: SharedFileRef) throws(PluginFailure) -> MappedFile {
        guard (0...maxBytes).contains(ref.byteCount), let url = allowedURL(ref) else { throw PluginFailure("shared file is not allowed") }
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)  // a planted FIFO must not block the host
        guard fd >= 0 else { throw PluginFailure("could not open shared file") }
        defer { Darwin.close(fd) }
        unlink(url.path)
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG, Int(info.st_size) >= ref.byteCount else { throw PluginFailure("shared file is not a regular file or smaller than announced") }
        guard ref.byteCount > 0 else { return MappedFile(memory: nil, count: 0) }
        guard let memory = mmap(nil, ref.byteCount, PROT_READ, MAP_PRIVATE, fd, 0), memory != MAP_FAILED else {
            throw PluginFailure("could not map shared file")
        }
        return MappedFile(memory: memory, count: ref.byteCount)
    }
}

nonisolated extension SharedFile {
    /// Unlinks a file a plugin named that the host won't map, so it doesn't pile up in the temporary directory.
    /// Paths `map` would refuse are left alone.
    static func discard(_ ref: SharedFileRef) {
        guard let url = allowedURL(ref) else { return }
        unlink(url.path)  // ENOENT is fine: `map` may already have unlinked it
    }

    /// The file's location, if it is a shared file directly inside the temporary directory.
    private static func allowedURL(_ ref: SharedFileRef) -> URL? {
        let url = URL(filePath: ref.path).standardizedFileURL
        guard url.deletingLastPathComponent().path == FileManager.default.temporaryDirectory.standardizedFileURL.path,
              url.lastPathComponent.hasPrefix(prefix) else { return nil }
        return url
    }
}

/// A read-only mapping, unmapped when the last reference goes away. Immutable after init.
nonisolated final class MappedFile: @unchecked Sendable {
    /// Valid only while this object is alive: `String(decoding: try SharedFile.map(ref).bytes, …)` reads unmapped
    /// memory, because the temporary is freed first. Hold the object (as the bitmap path does) or use `withMapped`.
    nonisolated(unsafe) let bytes: UnsafeRawBufferPointer

    fileprivate init(memory: UnsafeMutableRawPointer?, count: Int) {
        bytes = UnsafeRawBufferPointer(start: memory, count: count)
    }

    deinit {
        if let base = bytes.baseAddress { munmap(UnsafeMutableRawPointer(mutating: base), bytes.count) }
    }
}
