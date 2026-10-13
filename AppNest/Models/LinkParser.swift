import Foundation

/// Parses job application URLs to extract company and position details.
/// Supports common ATS formats (Greenhouse, Lever, Ashby, Workday, etc.).
struct LinkParser {

    struct ParsedResult {
        var companyName: String?
        var position: String?
        var jobType: ApplicationType?
        var jobURL: String?
        var isLinkedIn: Bool = false
        /// A real URL that isn't a job posting (a homepage, a search page, a social link).
        var isNotJobLink: Bool = false
    }

    /// The pasted text as a web URL, or nil when it isn't one. Bare domains get `https://`.
    /// Rejects whitespace (pasted sentences), hosts without a dot ("hello"), and non-web schemes.
    static func webURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, host.contains("."),
              let tld = host.split(separator: ".").last, tld.count >= 2, tld.allSatisfy(\.isLetter)
        else { return nil }
        return url
    }

    func parse(_ urlString: String) async -> ParsedResult {
        var result = ParsedResult(jobURL: urlString)
        guard let url = Self.webURL(from: urlString), let host = url.host else {
            result.isNotJobLink = true
            return result
        }
        result.jobURL = url.absoluteString

        // Clean up host
        let cleanHost = host.lowercased().replacingOccurrences(of: "www.", with: "")

        // 0. LinkedIn (cannot parse from URL directly)
        if cleanHost.contains("linkedin.com") {
            result.isLinkedIn = true
            return result
        }

        // gh_jid query param — Greenhouse widget embedded on a company's own domain
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let ghJid = components.queryItems?.first(where: { $0.name == "gh_jid" })?.value {
            let domainParts = cleanHost.split(separator: ".")
            if domainParts.count >= 2 {
                let label = String(domainParts[domainParts.count - 2])
                let company = Self.stripCareersAffix(label)
                result.companyName = formatName(company)
                // The board token is usually the bare company ("pinterest" on pinterestcareers.com).
                for token in Set([company, label]) {
                    if let fetched = await fetchGreenhouseJob(boardToken: token, jobID: ghJid) {
                        result.position = fetched.title
                        result.jobType = inferType(from: fetched.title)
                        return result
                    }
                }
            }
            // API miss: fall through so the title slug in the path can still be read.
        }

        // 1. Greenhouse (boards.greenhouse.io/companyname/jobs/12345)
        if cleanHost.contains("greenhouse.io") {
            let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
            if pathComponents.count >= 1 {
                let boardToken = pathComponents[0]
                result.companyName = formatName(boardToken)
                if pathComponents.count >= 3, pathComponents[1] == "jobs",
                   let fetched = await fetchGreenhouseJob(boardToken: boardToken, jobID: pathComponents[2]) {
                    result.position = fetched.title
                    result.jobType = inferType(from: fetched.title)
                }
            }
            return result
        }

        // 2. Lever (jobs.lever.co/companyname/1234-abcd)
        if cleanHost.contains("lever.co") {
            let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
            if pathComponents.count >= 1 {
                result.companyName = formatName(pathComponents[0])
            }
            return result
        }

        // 3. Ashby (jobs.ashbyhq.com/companyname/1234-abcd)
        if cleanHost.contains("ashbyhq.com") {
            let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
            if pathComponents.count >= 1 {
                result.companyName = formatName(pathComponents[0])
            }
            return result
        }

        // 4. Workday (company.myworkdayjobs.com/company/job/location/title_REQ123)
        if cleanHost.contains("myworkdayjobs.com") {
            let parts = cleanHost.split(separator: ".")
            if parts.count >= 3 {
                result.companyName = formatName(String(parts[0]))
            }
            let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
            if let last = pathComponents.last, last.contains("_") || last.contains("-") {
                let pos = formatPosition(last)
                result.position = pos
                result.jobType = inferType(from: pos)
            }
            return result
        }

        // 5. Careers pages (company.com/careers/...) or (careers.company.com/...)
        // Heuristic fallback for general domains — only when something says "job". Without
        // this, google.com/search?q=… became an application at "Google".
        // ponytail: keyword sniffing, not page fetching — a job page on a path with none of
        // these words is rejected. Fetch the page's JSON-LD JobPosting if that comes up.
        let jobSignals = ["career", "job", "position", "opening", "apply", "vacanc", "recruit", "posting", "talent", "hiring"]
        let haystack = (cleanHost + url.path).lowercased()
        guard jobSignals.contains(where: haystack.contains) else {
            result.isNotJobLink = true
            return result
        }
        let domainParts = cleanHost.split(separator: ".")
        if domainParts.count >= 2 {
            let primaryDomain = String(domainParts[domainParts.count - 2])
            if primaryDomain != "com" && primaryDomain != "co" && primaryDomain != "io" && primaryDomain != "net" && primaryDomain != "org" {
                if primaryDomain.lowercased() != "greenhouse" && primaryDomain.lowercased() != "lever" && primaryDomain.lowercased() != "ashbyhq" {
                    result.companyName = result.companyName ?? formatName(Self.stripCareersAffix(primaryDomain))
                }
            }
        }

        // Try to extract position from the last path component if it looks like a slug
        let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
        if let last = pathComponents.last, (last.contains("-") || last.contains("_")) && last.count > 5 {
            let isJustID = last.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) != nil
            if !isJustID {
                let pos = formatPosition(last)
                result.position = pos
                result.jobType = inferType(from: pos)
            }
        }

        return result
    }

    /// "pinterestcareers" → "pinterest", "jobsatacme" stays (no clean split). Keeps the label
    /// when stripping would leave nothing.
    static func stripCareersAffix(_ label: String) -> String {
        let lower = label.lowercased()
        // A remainder under 3 letters means the affix *was* the label ("careers" → "s").
        for affix in ["careers", "career", "jobs", "talent"] {
            if lower.hasSuffix(affix), lower.count - affix.count >= 3 { return String(lower.dropLast(affix.count)) }
            if lower.hasPrefix(affix), lower.count - affix.count >= 3 { return String(lower.dropFirst(affix.count)) }
        }
        return lower
    }

    // MARK: - Type Inference

    private func inferType(from title: String) -> ApplicationType? {
        let s = title.lowercased()
        if s.range(of: #"\bintern(?:ship|ships|s)?\b"#, options: .regularExpression) != nil { return .internship }
        if s.contains("co-op") || s.contains("co op") || s.contains("coop") { return .Co_op }
        if s.contains("part-time") || s.contains("part time") { return .partTime }
        if s.contains("full-time") || s.contains("full time") { return .fullTime }
        if s.contains("contract") { return .contract }
        if s.contains("temporary") || s.contains("temp ") { return .temporary }
        return nil
    }

    // MARK: - API Fetchers

    private struct GreenhouseJobResponse: Decodable {
        let title: String
    }

    private func fetchGreenhouseJob(boardToken: String, jobID: String) async -> GreenhouseJobResponse? {
        guard let url = URL(string: "https://boards-api.greenhouse.io/v1/boards/\(boardToken)/jobs/\(jobID)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode(GreenhouseJobResponse.self, from: data)
    }

    // MARK: - Formatters

    private func formatName(_ slug: String) -> String {
        return slug
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func formatPosition(_ slug: String) -> String {
        var str = slug

        // Remove trailing requisition IDs (e.g. "_REQ123" or "-12345")
        if let range = str.range(of: #"[_|-][A-Z0-9]{3,}$"#, options: .regularExpression) {
            str = String(str[..<range.lowerBound])
        }

        // Common workday prefix
        if str.hasPrefix("job/") {
            str = String(str.dropFirst(4))
        }

        return str
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
