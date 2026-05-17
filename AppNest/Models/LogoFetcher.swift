import Foundation

enum LogoFetcher {
    private static let cache = NSCache<NSString, NSData>()

    static func fetchLogoData(for company: String, darkMode: Bool = true) async -> Data? {
        let token = APIKeys.logoDev
        let query = company.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? company
        let theme = darkMode ? "dark" : "light"

        guard let searchURL = URL(string: "https://api.logo.dev/search?q=\(query)&token=\(token)") else { return nil }

        do {
            let (searchData, _) = try await URLSession.shared.data(from: searchURL)
            let results = try JSONDecoder().decode([LogoSearchResult].self, from: searchData)
            guard let domain = results.first?.domain else { return nil }

            let cacheKey = "\(domain)_\(theme)" as NSString
            if let cached = cache.object(forKey: cacheKey) {
                return cached as Data
            }

            guard let logoURL = URL(string: "https://img.logo.dev/\(domain)?token=\(token)&size=256&theme=\(theme)&format=png") else { return nil }
            let (logoData, response) = try await URLSession.shared.data(from: logoURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

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
