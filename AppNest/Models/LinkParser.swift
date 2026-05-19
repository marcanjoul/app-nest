import Foundation

/// Parses job application URLs to extract company and position details.
/// Supports common ATS formats (Greenhouse, Lever, Ashby, Workday, etc.).
struct LinkParser {

    struct ParsedResult {
        var companyName: String?
        var position: String?
        var jobURL: String?
        var isLinkedIn: Bool = false
    }

    func parse(_ urlString: String) -> ParsedResult {
        var result = ParsedResult(jobURL: urlString)
        guard let url = URL(string: urlString), let host = url.host else {
            return result
        }

        // Clean up host
        let cleanHost = host.lowercased().replacingOccurrences(of: "www.", with: "")

        // 0. LinkedIn (cannot parse from URL directly)
        if cleanHost.contains("linkedin.com") {
            result.isLinkedIn = true
            return result
        }

        // 1. Greenhouse (boards.greenhouse.io/companyname/jobs/12345)
        if cleanHost.contains("greenhouse.io") {
            let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
            if pathComponents.count >= 1 {
                result.companyName = formatName(pathComponents[0])
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
            // Host is usually company.myworkdayjobs.com
            let parts = cleanHost.split(separator: ".")
            if parts.count >= 3 {
                result.companyName = formatName(String(parts[0]))
            }
            // Path often ends with title_REQ123
            let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
            if let last = pathComponents.last, last.contains("_") || last.contains("-") {
                result.position = formatPosition(last)
            }
            return result
        }

        // 5. Careers pages (company.com/careers/...) or (careers.company.com/...)
        // Heuristic fallback for general domains
        let domainParts = cleanHost.split(separator: ".")
        if domainParts.count >= 2 {
            let primaryDomain = String(domainParts[domainParts.count - 2])
            if primaryDomain != "com" && primaryDomain != "co" && primaryDomain != "io" && primaryDomain != "net" && primaryDomain != "org" {
                if primaryDomain.lowercased() != "greenhouse" && primaryDomain.lowercased() != "lever" && primaryDomain.lowercased() != "ashbyhq" {
                    result.companyName = formatName(primaryDomain)
                }
            }
        }

        // Try to extract position from the last path component if it looks like a slug
        let pathComponents = url.pathComponents.filter { !$0.isEmpty && $0 != "/" }
        if let last = pathComponents.last, (last.contains("-") || last.contains("_")) && last.count > 5 {
            // Check if it's purely alphanumeric noise (like an ID)
            let isJustID = last.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) != nil
            if !isJustID {
                 result.position = formatPosition(last)
            }
        }

        return result
    }

    // MARK: - Formatters

    private func formatName(_ slug: String) -> String {
        // e.g. "acme-corp" -> "Acme Corp"
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
