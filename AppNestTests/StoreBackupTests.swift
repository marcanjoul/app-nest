import Foundation
import Testing
@testable import AppNest

/// These cover the path that runs when a migration has already gone wrong, which is
/// exactly when it can't be debugged by hand. Serialized because they redirect
/// `StoreBackup.supportURL` at a temp directory, which is process-wide state.
@Suite("Store backup", .serialized)
struct StoreBackupTests {

    private let fm = FileManager.default

    /// Stands in for the live store: the database plus the two sidecar files SQLite
    /// keeps beside it.
    private func makeStore(in dir: URL, contents: String = "rows") throws {
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for suffix in ["", "-shm", "-wal"] {
            try Data("\(contents)\(suffix)".utf8)
                .write(to: dir.appending(path: "default.store\(suffix)"))
        }
    }

    private func withTempSupport(_ body: (URL) throws -> Void) rethrows {
        let dir = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let original = StoreBackup.supportURL
        StoreBackup.supportURL = dir
        defer {
            StoreBackup.supportURL = original
            try? fm.removeItem(at: dir)
        }
        try body(dir)
    }

    @Test("a snapshot copies the database and both sidecar files")
    func snapshotCopiesWALFiles() throws {
        try withTempSupport { dir in
            try makeStore(in: dir)
            StoreBackup.snapshot()

            let snapshots = StoreBackup.available()
            #expect(snapshots.count == 1)

            // The -wal in particular: a copy without it can miss the most recent writes.
            for suffix in ["", "-shm", "-wal"] {
                let copied = snapshots[0].url.appending(path: "default.store\(suffix)")
                #expect(fm.fileExists(atPath: copied.path), "missing default.store\(suffix)")
            }
        }
    }

    @Test("nothing is copied when there is no store yet")
    func noStoreNoSnapshot() throws {
        try withTempSupport { dir in
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            StoreBackup.snapshot()
            #expect(StoreBackup.available().isEmpty)
        }
    }

    @Test("only the three most recent backups are kept")
    func prunesToRetentionLimit() throws {
        try withTempSupport { dir in
            try makeStore(in: dir)
            // Folder names are second-resolution, so space these out to get distinct ones.
            for _ in 0..<5 {
                StoreBackup.snapshot()
                Thread.sleep(forTimeInterval: 1.05)
            }
            #expect(StoreBackup.available().count == 3)
        }
    }

    @Test("backups are listed newest first")
    func listedNewestFirst() throws {
        try withTempSupport { dir in
            try makeStore(in: dir)
            StoreBackup.snapshot()
            Thread.sleep(forTimeInterval: 1.05)
            StoreBackup.snapshot()

            let snapshots = StoreBackup.available()
            #expect(snapshots.count == 2)
            #expect(snapshots[0].date >= snapshots[1].date)
        }
    }

    @Test("restoring puts the backed-up contents back")
    func restoreOverwritesLiveStore() throws {
        try withTempSupport { dir in
            try makeStore(in: dir, contents: "original")
            StoreBackup.snapshot()

            // Stand in for a migration replacing the store with an empty one.
            try makeStore(in: dir, contents: "wiped")
            #expect(try String(contentsOf: StoreBackup.storeURL, encoding: .utf8) == "wiped")

            let backup = try #require(StoreBackup.available().first)
            try StoreBackup.restore(backup)

            #expect(try String(contentsOf: StoreBackup.storeURL, encoding: .utf8) == "original")
        }
    }

    @Test("an unreadable store is moved aside, not deleted")
    func preserveBrokenMovesTheStore() throws {
        try withTempSupport { dir in
            try makeStore(in: dir, contents: "unreadable")

            let kept = try #require(StoreBackup.preserveBroken())

            // Gone from the live location so SwiftData can't overwrite it...
            #expect(!fm.fileExists(atPath: StoreBackup.storeURL.path))
            // ...but still on disk, which is the whole point.
            let saved = kept.appending(path: "default.store")
            #expect(try String(contentsOf: saved, encoding: .utf8) == "unreadable")
        }
    }

    @Test("preserving does nothing when there is no store")
    func preserveBrokenWithNoStore() throws {
        try withTempSupport { dir in
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            #expect(StoreBackup.preserveBroken() == nil)
        }
    }
}
