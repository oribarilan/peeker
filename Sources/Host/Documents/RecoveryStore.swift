import Foundation
import os

/// A document's unsaved edits, journaled so they survive a crash of the app. `fileModified` is the file's date when
/// the edits were made, so a relaunch can tell whether someone changed the file since.
nonisolated struct RecoveryRecord: Codable, Equatable, Sendable {
    let id: String
    let url: URL
    let pluginID: String
    let fileModified: Date?
    let edits: Edits
}

/// Recovery records, one JSON file `<id>.json` each, in a directory only the user can read (records hold private
/// text). Never touches the documents themselves. All file work runs in order on one serial queue, so a background
/// write can't land after a later remove; encoding a 10 MB text took about 18 ms, too long for the main thread.
nonisolated final class RecoveryStore: Sendable {
    let directory: URL
    private let queue = DispatchQueue(label: "dev.peeker.recovery")
    static let shared = RecoveryStore(directory: .applicationSupportDirectory
        .appending(path: Bundle.main.bundleIdentifier ?? "dev.peeker", directoryHint: .isDirectory)
        .appending(path: "Recovery", directoryHint: .isDirectory))
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "recovery")

    init(directory: URL) {
        self.directory = directory
    }

    /// Writes atomically, replacing any record with the same id.
    func write(_ record: RecoveryRecord) throws {
        try queue.sync { try writeNow(record) }
    }

    /// `write` without waiting; a failure goes to the log.
    func writeInBackground(_ record: RecoveryRecord) {
        queue.async { [self] in
            do { try writeNow(record) } catch {
                Self.log.error("can't write recovery record \(record.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Waits for earlier background writes, so the record is gone when this returns.
    func remove(id: String) {
        queue.sync { removeNow(id: id) }
    }

    /// Every readable record, most recently written first. Unreadable files are skipped and logged.
    func all() -> [RecoveryRecord] {
        queue.sync { allNow() }
    }

    private func writeNow(_ record: RecoveryRecord) throws {
        let file = try file(for: record.id)
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(record).write(to: file, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    private func removeNow(id: String) {
        do {
            try FileManager.default.removeItem(at: try file(for: id))
        } catch CocoaError.fileNoSuchFile {
            // Nothing was journaled yet.
        } catch {
            Self.log.error("can't remove recovery record \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func allNow() -> [RecoveryRecord] {
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            Self.log.error("can't list recovery records: \(error.localizedDescription, privacy: .public)")
            return []
        }
        var records: [(record: RecoveryRecord, written: Date)] = []
        for file in files where file.pathExtension == "json" {
            do {
                let record = try JSONDecoder().decode(RecoveryRecord.self, from: Data(contentsOf: file))
                // A record must live in its own id's file, or removing it by id would leave it behind.
                guard file.lastPathComponent == "\(record.id).json" else { throw CocoaError(.fileReadCorruptFile) }
                records.append((record, try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast))
            } catch {
                Self.log.error("skipped unreadable recovery record \(file.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return records.sorted { $0.written > $1.written }.map(\.record)
    }

    /// Ids are app-generated UUIDs; anything but letters, digits and dashes could name a file outside the directory.
    private func file(for id: String) throws -> URL {
        guard !id.isEmpty, id.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-") }) else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return directory.appending(path: "\(id).json", directoryHint: .notDirectory)
    }
}
