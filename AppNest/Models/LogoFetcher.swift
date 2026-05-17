import Foundation

enum LogoFetcher {
    private static let cache = NSCache<NSString, NSData>()

    static func fetchLogoData(for company: String, darkMode: Bool = true) async -> Data? {
        let token = APIKeys.logoDev
        let theme = darkMode ? "dark" : "light"
        let query = company.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? company

        guard let searchURL = URL(string: "https://api.logo.dev/search?q=\(query)&token=\(token)") else { return nil }

        do {
            let (searchData, searchResponse) = try await URLSession.shared.data(from: searchURL)
            guard (searchResponse as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            let results = try JSONDecoder().decode([LogoSearchResult].self, from: searchData)
            guard let domain = results.first?.domain else { return nil }

            let cacheKey = "\(domain)_\(theme)" as NSString
            if let cached = cache.object(forKey: cacheKey) { return cached as Data }

            guard let logoURL = URL(string: "https://img.logo.dev/\(domain)?token=\(token)&size=256&theme=\(theme)") else { return nil }
            let (logoData, logoResponse) = try await URLSession.shared.data(from: logoURL)
            guard (logoResponse as? HTTPURLResponse)?.statusCode == 200, !logoData.isEmpty else { return nil }

            cache.setObject(logoData as NSData, forKey: cacheKey)
            return logoData
        } catch {
            return nil
        }
    }
}

private struct LogoSearchResult: Decodable {
    let domain: String
}
