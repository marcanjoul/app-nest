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

        // Step 1: Search for the company domain
        guard let results = await searchCompanies(company) else { return nil }
        guard let domain = results.first?.domain else {
            recordMiss(key)   // the search succeeded and knows of no such company
            return nil
        }

        // Step 2: Fetch the logo from the CDN
        return await fetchLogoData(domain: domain, company: company)
    }

    /// Skips the search when the domain is already known — a suggestion the user picked.
    static func fetchLogoData(domain: String, company: String) async -> Data? {
        let key = company.lowercased()
        if let cached = cache.object(forKey: key as NSString) { return cached as Data }

        guard let logoURL = logoURL(domain: domain, size: 256) else { return nil }
        guard let (logoData, logoResponse) = try? await URLSession.shared.data(from: logoURL) else { return nil }
        let logoStatus = (logoResponse as? HTTPURLResponse)?.statusCode
        guard logoStatus == 200, !logoData.isEmpty else {
            if logoStatus == 404 { recordMiss(key) }
            return nil
        }

        cache.setObject(logoData as NSData, forKey: key as NSString)
        try? logoData.write(to: diskURL(for: key), options: .atomic)
        return logoData
    }

    static func logoURL(domain: String, size: Int) -> URL? {
        URL(string: "https://img.logo.dev/\(domain)?token=\(APIKeys.logoDevPublicKey)&size=\(size)")
    }

    // MARK: - Company search

    struct Company: Decodable, Hashable {
        let name: String
        let domain: String

        private enum CodingKeys: String, CodingKey { case name, domain }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            domain = try c.decode(String.self, forKey: .domain)
            name = (try? c.decode(String.self, forKey: .name)) ?? domain
        }
    }

    private final class SearchBox { let companies: [Company]; init(_ c: [Company]) { companies = c } }
    private static let searchCache = NSCache<NSString, SearchBox>()

    /// Companies matching `query`, best match first. nil means the request failed (not "no matches").
    /// Cached per query so type-ahead suggestions and the logo fetch share one request.
    static func searchCompanies(_ query: String) async -> [Company]? {
        let cacheKey = query.lowercased() as NSString
        if let hit = searchCache.object(forKey: cacheKey) { return hit.companies }

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let searchURL = URL(string: "https://api.logo.dev/search?q=\(encoded)") else { return nil }
        var request = URLRequest(url: searchURL)
        request.setValue("Bearer \(APIKeys.logoDevSecretKey)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let results = try? JSONDecoder().decode([Company].self, from: data)
        else { return nil }

        let companies = results.filter { !$0.domain.isEmpty }
        searchCache.setObject(SearchBox(companies), forKey: cacheKey)
        return companies
    }
}
