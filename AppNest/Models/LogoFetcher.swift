import CryptoKit
import Foundation

enum LogoFetcher {
    private static let cache = NSCache<NSString, NSData>()

    // ponytail: plain files in Caches — the system evicts them under pressure and no schema
    // is needed. Logos are also stored per-job in SwiftData; this only saves the fetch when a
    // *new* job lands at a company seen in an earlier launch.
    private static let diskCacheURL: URL = {
        let dir = URL.cachesDirectory.appending(path: "logos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// A company Logo.dev has never heard of costs two requests per card appearance, forever.
    /// An empty file is the tombstone; it expires so a company added later still gets picked up.
    private static let missRetryInterval: TimeInterval = 30 * 24 * 60 * 60

    private static func recordMiss(_ key: String) {
        try? Data().write(to: diskURL(for: key), options: .atomic)
    }

    private static func missIsStillFresh(_ url: URL) -> Bool {
        guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return false }
        return Date().timeIntervalSince(modified) < missRetryInterval
    }

    private static func diskURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return diskCacheURL.appending(path: digest)
    }

    static func fetchLogoData(for company: String, darkMode: Bool = true) async -> Data? {
        // ponytail: check the cache before the search round-trip, otherwise every card
        // still pays a network request on appear even when the logo is already in memory.
        let key = company.lowercased()
        let companyKey = key as NSString
        if let cached = cache.object(forKey: companyKey) { return cached as Data }
        let diskFile = diskURL(for: key)
        if let onDisk = try? Data(contentsOf: diskFile) {
            if !onDisk.isEmpty {
                cache.setObject(onDisk as NSData, forKey: companyKey)
                return onDisk
            }
            if missIsStillFresh(diskFile) { return nil }
        }

        let query = company.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? company

        // Step 1: Search for the company domain using the secret key
        guard let searchURL = URL(string: "https://api.logo.dev/search?q=\(query)") else { return nil }
        var searchRequest = URLRequest(url: searchURL)
        searchRequest.setValue("Bearer \(APIKeys.logoDevSecretKey)", forHTTPHeaderField: "Authorization")

        do {
            let (searchData, searchResponse) = try await URLSession.shared.data(for: searchRequest)
            guard (searchResponse as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            let results = try JSONDecoder().decode([LogoSearchResult].self, from: searchData)
            guard let domain = results.first?.domain, !domain.isEmpty else {
                recordMiss(key)   // the search succeeded and knows of no such company
                return nil
            }

            // Step 2: Fetch the logo from the CDN using the publishable key
            guard let logoURL = URL(string: "https://img.logo.dev/\(domain)?token=\(APIKeys.logoDevPublicKey)&size=256") else { return nil }
            let (logoData, logoResponse) = try await URLSession.shared.data(from: logoURL)
            let logoStatus = (logoResponse as? HTTPURLResponse)?.statusCode
            guard logoStatus == 200, !logoData.isEmpty else {
                if logoStatus == 404 { recordMiss(key) }
                return nil
            }

            cache.setObject(logoData as NSData, forKey: companyKey)
            try? logoData.write(to: diskFile, options: .atomic)
            return logoData
        } catch {
            return nil
        }
    }
}

private struct LogoSearchResult: Decodable {
    let domain: String
}
