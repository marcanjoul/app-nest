import Foundation

/// Transient data passed from the Share Extension to the main app via App Group UserDefaults.
struct PendingJobImport: Codable, Equatable {
    var companyName: String
    var position: String
    var sourceURL: String?

    static let groupID = "group.com.example.mark.appnest"
    static let defaultsKey = "pendingJobImport"

    static func consume() -> PendingJobImport? {
        let defaults = UserDefaults(suiteName: groupID)
        guard let data = defaults?.data(forKey: defaultsKey),
              let pending = try? JSONDecoder().decode(PendingJobImport.self, from: data)
        else { return nil }
        defaults?.removeObject(forKey: defaultsKey)
        return pending
    }
}
