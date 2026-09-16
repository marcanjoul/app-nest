import Foundation
import SwiftData

/// Plain file copies of the SwiftData store, taken when it is known to hold data.
///
/// SwiftData's implicit migration handles added optional properties and nothing harder.
/// A change it can't infer — a removed non-optional property, a changed type — either
/// fails to open or opens onto an empty store, and in both cases the old rows are gone
/// with no built-in way back. A copy on disk is the only thing that survives that.
enum StoreBackup {

    /// SQLite keeps a write-ahead log and shared-memory file beside the database. Copying
    /// `default.store` on its own can miss writes still sitting in the -wal.
    private static let suffixes = ["", "-shm", "-wal"]

    /// ponytail: three is arbitrary — enough to step back past a bad launch, small enough
    /// (~100KB each) not to think about. Raise it if migrations start going wrong in pairs.
    private static let keep = 3

    /// Settable so tests can exercise the copy/prune/restore logic against a temp
    /// directory instead of the real store.
    static var supportURL: URL = .applicationSupportDirectory
    static var storeURL: URL { supportURL.appending(path: "default.store") }
    private static var backupsURL: URL {
        supportURL.appending(path: "Backups", directoryHint: .isDirectory)
    }
    private static var brokenURL: URL {
        supportURL.appending(path: "Broken", directoryHint: .isDirectory)
    }

    struct Snapshot: Identifiable, Hashable {
        let url: URL
        let date: Date
        let byteCount: Int
        var id: URL { url }

        var displayName: String { date.formatted(date: .abbreviated, time: .shortened) }
        var displaySize: String {
            ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
        }
    }

    // MARK: - Taking a backup

    /// Copies the store only when it currently holds at least one application.
    ///
    /// The count is the whole point: if a migration silently empties the store, backing it
    /// up regardless would push the last good copies out of the retention window within
    /// three launches — losing the data exactly when it's needed.
    @MainActor
    static func snapshotIfPopulated(_ container: ModelContainer) {
        let count = (try? container.mainContext.fetchCount(FetchDescriptor<JobApplication>())) ?? 0
        guard count > 0 else { return }
        snapshot()
    }

    /// Internal rather than private so the retention logic is reachable from tests.
    static func snapshot() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }

        // Filesystem-safe and sorts chronologically as a string.
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd-HHmmss"
        let folder = backupsURL.appending(path: stamp.string(from: Date()), directoryHint: .isDirectory)

        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for suffix in suffixes {
                let src = supportURL.appending(path: "default.store\(suffix)")
                guard fm.fileExists(atPath: src.path) else { continue }
                try fm.copyItem(at: src, to: folder.appending(path: "default.store\(suffix)"))
            }
            prune()
        } catch {
            // A failed backup must never take the app down with it — the store is still fine.
            try? fm.removeItem(at: folder)
        }
    }

    private static func prune() {
        let extra = available().dropFirst(keep)
        for snapshot in extra {
            try? FileManager.default.removeItem(at: snapshot.url)
        }
    }

    // MARK: - Reading backups

    /// Newest first.
    static func available() -> [Snapshot] {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return folders.compactMap { folder -> Snapshot? in
            let store = folder.appending(path: "default.store")
            guard fm.fileExists(atPath: store.path) else { return nil }
            let values = try? store.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return Snapshot(url: folder,
                            date: values?.contentModificationDate ?? .distantPast,
                            byteCount: values?.fileSize ?? 0)
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: - Recovery

    /// Moves a store that wouldn't open out of the way instead of letting SwiftData
    /// replace it. Returns where it went, so the failure can say so.
    @discardableResult
    static func preserveBroken() -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return nil }

        let folder = brokenURL.appending(path: "\(Int(Date().timeIntervalSince1970))",
                                         directoryHint: .isDirectory)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for suffix in suffixes {
                let src = supportURL.appending(path: "default.store\(suffix)")
                guard fm.fileExists(atPath: src.path) else { continue }
                try fm.moveItem(at: src, to: folder.appending(path: "default.store\(suffix)"))
            }
            return folder
        } catch {
            return nil
        }
    }

    /// Copies a snapshot back over the live store. The container is already open by the
    /// time a user can reach this, so the app has to be relaunched for it to take effect.
    static func restore(_ snapshot: Snapshot) throws {
        let fm = FileManager.default
        for suffix in suffixes {
            let dst = supportURL.appending(path: "default.store\(suffix)")
            if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }

            let src = snapshot.url.appending(path: "default.store\(suffix)")
            guard fm.fileExists(atPath: src.path) else { continue }
            try fm.copyItem(at: src, to: dst)
        }
    }
}
