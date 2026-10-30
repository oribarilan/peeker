import Foundation

enum FileReplacement {
    /// Writes `data` to the file at `path` (or the file a symlink there points to) atomically, keeping its
    /// permissions. A file deleted or moved since it was opened is created again, with the default mode. On any
    /// failure the original is left as it was.
    static func replaceContents(ofFileAt path: String, with data: Data) throws(PluginFailure) {
        let files = FileManager.default
        let name = URL(filePath: path).lastPathComponent
        let target = URL(filePath: path).resolvingSymlinksInPath()
        let directory = target.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PluginFailure("“\(name)” can't be saved because its folder no longer exists.")
        }
        let exists = files.fileExists(atPath: target.path)
        // A dangling link: replacing it with a file would quietly cut it loose from where it pointed.
        if !exists, (try? files.destinationOfSymbolicLink(atPath: target.path)) != nil {
            throw PluginFailure("“\(name)” can't be saved because the file its link points to no longer exists.")
        }
        // The temporary file goes next to the target, so the directory must be writable too.
        guard !exists || files.isWritableFile(atPath: target.path), files.isWritableFile(atPath: directory.path) else {
            throw PluginFailure("You don't have permission to save “\(name)”.", code: .notWritable)
        }
        let permissions = exists ? try PluginFailure.catching { try files.attributesOfItem(atPath: target.path)[.posixPermissions] } : nil
        let temporary = directory.appending(path: ".\(target.lastPathComponent).peeker-save-\(UUID().uuidString)")
        let result: URL
        do {
            if exists {
                try writeNew(temporary, data, permissions: permissions)
                result = try files.replaceItemAt(target, withItemAt: temporary) ?? target
            } else {
                try writeNew(temporary, data, permissions: NSNumber(value: 0o644 & ~currentUmask()))
                try files.moveItem(at: temporary, to: target)  // fails rather than replace a file that just appeared
                return
            }
        } catch {
            unlink(temporary.path)  // already gone if the replace went through
            throw PluginFailure(error.localizedDescription)
        }
        // The new contents are on disk by now, so a problem here is no failed save.
        guard let permissions else { return }
        do {
            try files.setAttributes([.posixPermissions: permissions], ofItemAtPath: result.path)
        } catch {
            FileHandle.standardError.write(Data("saved “\(name)” but couldn't restore its permissions: \(error.localizedDescription)\n".utf8))
        }
    }

    /// The process's file mode mask. Reading it means setting it, so it is put straight back; plugins are single-threaded.
    private static func currentUmask() -> mode_t {
        let mask = umask(0)
        umask(mask)
        return mask
    }

    /// Creates `url` owner-only, writes `data`, then applies `permissions`, so the new contents are never readable by
    /// more people than the original's.
    private static func writeNew(_ url: URL, _ data: Data, permissions: Any?) throws {
        let fd = Darwin.open(url.path, O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        try handle.write(contentsOf: data)
        if let mode = (permissions as? NSNumber)?.uint16Value, fchmod(fd, mode_t(mode)) != 0 {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try handle.close()
    }
}
