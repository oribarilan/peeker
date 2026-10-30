import Foundation
import os

public nonisolated enum FileReplacement {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "files")

    /// Writes `data` to the file at `path` (or the file a symlink there points to) atomically, keeping its
    /// permissions. A file deleted or moved since it was opened is created again, with the default mode. On any
    /// failure the original is left as it was. Safe to call from any thread.
    public static func replaceContents(ofFileAt path: String, with data: Data) throws(PluginError) {
        let files = FileManager.default
        let name = URL(filePath: path).lastPathComponent
        let target = URL(filePath: path).resolvingSymlinksInPath()
        let directory = target.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PluginError("“\(name)” can't be saved because its folder no longer exists.")
        }
        let exists = files.fileExists(atPath: target.path)
        // A dangling link: replacing it with a file would quietly cut it loose from where it pointed.
        if !exists, (try? files.destinationOfSymbolicLink(atPath: target.path)) != nil {
            throw PluginError("“\(name)” can't be saved because the file its link points to no longer exists.")
        }
        // The temporary file goes next to the target, so the directory must be writable too.
        guard !exists || files.isWritableFile(atPath: target.path), files.isWritableFile(atPath: directory.path) else {
            throw PluginError("You don't have permission to save “\(name)”.", code: .notWritable)
        }
        let permissions = exists ? try PluginError.catching { try files.attributesOfItem(atPath: target.path)[.posixPermissions] } : nil
        let temporary = directory.appending(path: ".\(target.lastPathComponent).peeker-save-\(UUID().uuidString)")
        let result: URL
        do {
            if exists {
                try writeNew(temporary, data, createMode: 0o600, permissions: permissions)
                result = try files.replaceItemAt(target, withItemAt: temporary) ?? target
            } else {
                // The kernel applies the umask to the create mode, so the new file gets the default mode without
                // reading the umask, which can only be read by changing it for every thread.
                try writeNew(temporary, data, createMode: 0o644, permissions: nil)
                try files.moveItem(at: temporary, to: target)  // fails rather than replace a file that just appeared
                return
            }
        } catch {
            unlink(temporary.path)  // already gone if the replace went through
            throw PluginError(error.localizedDescription)
        }
        // The new contents are on disk by now, so a problem here is no failed save.
        guard let permissions else { return }
        do {
            try files.setAttributes([.posixPermissions: permissions], ofItemAtPath: result.path)
        } catch {
            log.error("saved \(name, privacy: .private) but couldn't restore its permissions: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Creates `url` with `createMode`, writes `data`, then applies `permissions`, so the new contents are never
    /// readable by more people than the original's.
    private static func writeNew(_ url: URL, _ data: Data, createMode: mode_t, permissions: Any?) throws {
        let fd = Darwin.open(url.path, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, createMode)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        try handle.write(contentsOf: data)
        if let mode = (permissions as? NSNumber)?.uint16Value, fchmod(fd, mode_t(mode)) != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try handle.close()
    }
}
