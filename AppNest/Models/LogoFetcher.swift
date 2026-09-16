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
        if let onDisk = try? Data(contentsOf: diskURL(for: key)), !onDisk.isEmpty {
            cache.setObject(onDisk as NSData, forKey: companyKey)
            return onDisk
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
            guard let domain = results.first?.domain, !domain.isEmpty else { return nil }

            // Step 2: Fetch the logo from the CDN using the publishable key
            guard let logoURL = URL(string: "https://img.logo.dev/\(domain)?token=\(APIKeys.logoDevPublicKey)&size=256") else { return nil }
            let (logoData, logoResponse) = try await URLSession.shared.data(from: logoURL)
            guard (logoResponse as? HTTPURLResponse)?.statusCode == 200, !logoData.isEmpty else { return nil }

            cache.setObject(logoData as NSData, forKey: companyKey)
            try? logoData.write(to: diskURL(for: key), options: .atomic)
            return logoData
        } catch {
            return nil
        }
    }
}

private struct LogoSearchResult: Decodable {
    let domain: String
}
