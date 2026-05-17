import Foundation

enum LogoFetcher {
    private static let cache = NSCache<NSString, NSData>()

    static func fetchLogoData(for company: String, darkMode: Bool = true) async -> Data? {
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

            if let cached = cache.object(forKey: domain as NSString) { return cached as Data }

            // Step 2: Fetch the logo from the CDN using the publishable key
            guard let logoURL = URL(string: "https://img.logo.dev/\(domain)?token=\(APIKeys.logoDevPublicKey)&size=256") else { return nil }
            let (logoData, logoResponse) = try await URLSession.shared.data(from: logoURL)
            guard (logoResponse as? HTTPURLResponse)?.statusCode == 200, !logoData.isEmpty else { return nil }

            cache.setObject(logoData as NSData, forKey: domain as NSString)
            return logoData
        } catch {
            return nil
        }
    }
}

private struct LogoSearchResult: Decodable {
    let domain: String
}
