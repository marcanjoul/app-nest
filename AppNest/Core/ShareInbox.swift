import Foundation

/// Items the Share extension (AppNestShare) dropped in the App Group, one text file per share.
enum ShareInbox {
    // Must match ShareViewController in the extension.
    static let appGroup = "group.com.example.mark.AppNest"

    private static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("ShareInbox", isDirectory: true)
    }

    /// The newest shared item, clearing the inbox. Older ones are dropped: the user acted on
    /// the latest share, and replaying stale ones later would be confusing.
    static func take() -> String? {
        guard let dir = directory,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil),
              !files.isEmpty else { return nil }
        // Names start with a timestamp, so name order is share order.
        let newest = files.max { $0.lastPathComponent < $1.lastPathComponent }
        let text = newest.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        return text
    }
}
