import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared constants

private let appGroupID       = "group.com.example.mark.appnest"
private let pendingImportKey = "pendingJobImport"
private let logoPublicKey    = "pk_PaR2J13cQXyRshj6wOxhVw"
private let logoSecretKey    = "sk_SFlbaAHcRcWM_u3MDsFnPw"
private let shareAccent      = Color(red: 0.35, green: 0.65, blue: 0.96)

// MARK: - Local enum mirrors (raw values match main app enums for Codable compat)

private enum ShareJobType: String, CaseIterable {
    case fullTime   = "Full Time"
    case partTime   = "Part Time"
    case contract   = "Contract"
    case internship = "Internship"
    case coop       = "Co-op"
    case temporary  = "Temporary"

    var color: Color {
        switch self {
        case .fullTime:   return Color(red: 0.35, green: 0.65, blue: 0.96)
        case .partTime:   return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .internship: return Color(red: 0.93, green: 0.38, blue: 0.44)
        case .contract:   return Color(red: 0.62, green: 0.52, blue: 0.96)
        case .coop:       return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .temporary:  return Color(red: 0.96, green: 0.52, blue: 0.62)
        }
    }

    var icon: String {
        switch self {
        case .fullTime:   return "briefcase.fill"
        case .partTime:   return "clock.fill"
        case .internship: return "graduationcap.fill"
        case .contract:   return "doc.text.fill"
        case .coop:       return "building.2.fill"
        case .temporary:  return "timer"
        }
    }
}

private enum ShareJobStatus: String, CaseIterable {
    case toApply   = "To Apply"
    case applied   = "Applied"
    case interview = "Interview"
    case offer     = "Offer"
    case rejected  = "Rejected"

    var color: Color {
        switch self {
        case .toApply:   return Color(red: 0.58, green: 0.62, blue: 0.82)
        case .applied:   return Color(red: 0.35, green: 0.65, blue: 0.96)
        case .interview: return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .offer:     return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .rejected:  return Color(red: 0.93, green: 0.38, blue: 0.44)
        }
    }

    var icon: String {
        switch self {
        case .toApply:   return "plus.circle.fill"
        case .applied:   return "paperplane.fill"
        case .interview: return "person.2.fill"
        case .offer:     return "checkmark.seal.fill"
        case .rejected:  return "xmark.circle.fill"
        }
    }
}

private enum ShareJobSeason: String, CaseIterable {
    case winter = "Winter"
    case spring = "Spring"
    case summer = "Summer"
    case fall   = "Fall"

    var color: Color {
        switch self {
        case .winter: return Color(red: 0.55, green: 0.75, blue: 0.95)
        case .spring: return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .summer: return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .fall:   return Color(red: 0.93, green: 0.48, blue: 0.28)
        }
    }

    var icon: String {
        switch self {
        case .winter: return "snowflake"
        case .spring: return "leaf.fill"
        case .summer: return "sun.max.fill"
        case .fall:   return "wind"
        }
    }
}

// MARK: - Email parser (Foundation-only, no SwiftData dependency)

private struct ShareEmailParser {

    struct Result {
        var companyName: String?
        var position: String?
        var jobType: ShareJobType?
        var status: ShareJobStatus?
    }

    func parse(_ text: String) -> Result {
        Result(
            companyName: extractCompany(from: text),
            position:    extractPosition(from: text),
            jobType:     extractJobType(from: text),
            status:      extractStatus(from: text)
        )
    }

    // MARK: Company

    private func extractCompany(from text: String) -> String? {
        let patterns = [
            #"(?:joining|join)\s+(?:our\s+team\s+at\s+|the\s+team\s+at\s+)?([A-Z][A-Za-z0-9&\s\.]+?)(?:\s+and\b|\s+for\b|\.|,|\!|\n|$)"#,
            #"(?:role|position|opportunity|internship|job)\s+(?:at|with)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\s+and\b|\s+for\b|\.|,|\!|\n|$)"#,
            #"(?:apply|applied|applying)\s+(?:to|for)\s+.+?\s+at\s+([A-Z][A-Za-z0-9&®\s\.]+?)(?:\s+on\b|\s+via\b|\s+through\b|\s+and\b|\s+for\b|\.|,|\!|\n|$)"#,
            #"(?:apply|applied|applying)\s+(?:to|at|for)\s+(?!the\b|a\b|an\b)([A-Z][A-Za-z0-9&\s\.]+?)(?:\s+through\b|\s+via\b|\s+and\b|\s+for\b|\.|,|\!|\n|$)"#,
            #"(?:application|applying|applied)\s+to\s+([A-Z][A-Za-z0-9&\.]+(?:\s+[A-Z][A-Za-z0-9&\.]+){0,2})(?:'s)?\b"#,
            #"(?:welcome to|offer from)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\s+and\b|\s+for\b|\.|,|\!|\n|$)"#,
            #"(?:here\s+at|team\s+at)\s+([A-Z][A-Za-z0-9&\.]+(?:\s+[A-Z][A-Za-z0-9&\.]+){0,2})\b"#,
            #"(?:interest in|interested in)\s+(?!joining\b|applying\b|working\b)([A-Z][A-Za-z0-9&\s\.]+?)(?:\s+and\b|\s+for\b|\.|,|\!|\n|$)"#,
        ]
        for pattern in patterns {
            guard let raw = capture(pattern, in: text), raw.first?.isUppercase == true else { continue }
            var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                       .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:®™"))
            for prefix in ["position ", "role ", "the position ", "the role ", "the "] {
                if s.lowercased().hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
            }
            if let r = s.range(of: #"\s*-\s*\d{4,}$"#, options: .regularExpression) { s = String(s[..<r.lowerBound]) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty && s.count < 100 { return s }
        }
        return nil
    }

    // MARK: Position

    private func extractPosition(from text: String) -> String? {
        let patterns = [
            // "applied/applying for/to [POSITION]" — flexible terminators
            #"(?:\bapply\b|application|applied|applying)\s+(?:for|to)\s+(?:the\s+)?(.+?)(?:\s+(?:position|role)\b|\s+(?:at|@)\s+|\s+with\s+(?=[A-Z])|\s+and\s+(?=(?:we|i|they|the|our|a|an|you)\b)|[.,\n]|$)"#,
            // "applied for/to [POSITION] at/with [COMPANY]"
            #"(?:application|applied|applying)\s+(?:for|to)\s+(?:the\s+)?(.+?)\s+(?:at|with|@)\s+"#,
            // "interest in [the] [POSITION] role/position" — rejection/status emails
            #"interest\s+in\s+(?:the\s+)?(.+?)\s+(?:role|position)\b"#,
            // "the [POSITION] role/position at [COMPANY]"
            #"the\s+(.+?)\s+(?:role|position)\s+(?:at|with|@)\s+[A-Z]"#,
            // "interview you for [POSITION]"
            #"interview(?:ing)?\s+you\s+for\s+(?:the\s+)?(.+?)(?:\s+(?:at|with|@)\s+|,|\.\s|\n|$)"#,
            // "offer [you] [the] [POSITION] role/position"
            #"offer\s+(?:you\s+)?(?:the\s+)?(.+?)\s+(?:role|position)"#,
            // label: "role:" / "position:" / "job title:" / "title:"
            #"(?:role|position|job title|title)\s*:\s*(.+?)(?:\n|$)"#,
            // "position/role of [POSITION]"
            #"(?:role|position)\s+of\s+(.+?)(?:\s+(?:at|with|@)\s+|[.,\n]|$)"#,
            // "as a/an [POSITION] at/with"
            #"as\s+an?\s+(.+?)\s+(?:at|with|@)\s+[A-Z]"#,
        ]
        for pattern in patterns {
            guard let raw = capture(pattern, in: text) else { continue }
            var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                       .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
            for noise in ["for the ", "for a ", "for an ", "the ", "our ", "a ", "an "] {
                if s.lowercased().hasPrefix(noise) { s = String(s.dropFirst(noise.count)).trimmingCharacters(in: .whitespacesAndNewlines); break }
            }
            for suffix in [" role", " position"] {
                if s.lowercased().hasSuffix(suffix) { s = String(s.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines); break }
            }
            if !s.isEmpty && s.count < 100 { return s }
        }
        return nil
    }

    // MARK: Job Type

    private func extractJobType(from text: String) -> ShareJobType? {
        let lower = text.lowercased()
        if lower.contains("internship") || lower.contains(" intern ") || lower.contains(" intern\n") { return .internship }
        if lower.contains("co-op") || lower.contains("coop") || lower.contains("co op")              { return .coop }
        if lower.contains("part-time") || lower.contains("part time")                                { return .partTime }
        if lower.contains("full-time") || lower.contains("full time")                                { return .fullTime }
        if lower.contains("contract position") || lower.contains("contractor")                       { return .contract }
        if lower.contains("temporary position") || lower.contains("temporary role")                  { return .temporary }
        return nil
    }

    // MARK: Status

    private func extractStatus(from text: String) -> ShareJobStatus? {
        let lower = text.lowercased()
        for p in ["pleased to offer", "we'd like to offer", "offer letter", "welcome to the team", "welcome aboard", "extend an offer"] {
            if lower.contains(p) { return .offer }
        }
        for p in ["unfortunately", "not moving forward", "will not be moving", "regret to inform",
                  "unable to offer", "after careful consideration", "not been selected", "have not been selected"] {
            if lower.contains(p) { return .rejected }
        }
        for p in ["schedule an interview", "interview invitation", "like to interview", "next round",
                  "phone screen", "technical interview", "selected for an interview", "invite you to interview"] {
            if lower.contains(p) { return .interview }
        }
        for p in ["thank you for applying", "application received", "successfully submitted",
                  "we have received your application", "confirm your application"] {
            if lower.contains(p) { return .applied }
        }
        return nil
    }

    // MARK: Helper

    private func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: ns),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

// MARK: - Pending import model (mirrors AppNest/Models/PendingJobImport.swift)

struct SharePendingImport: Codable {
    var companyName: String
    var position: String
    var sourceURL: String?
    var jobType: String?
    var status: String?
    var season: String?
    var notes: String?
}

// MARK: - View controller

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let scheme: ColorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        Task { @MainActor [weak self] in
            guard let self else { return }
            let (pending, rawURL, emailText) = await self.extractJobInfo()
            let rootView: AnyView
            if let emailText {
                let parsed = ShareEmailParser().parse(emailText)
                let pending = SharePendingImport(
                    companyName: parsed.companyName ?? "",
                    position:    parsed.position ?? "",
                    jobType:     parsed.jobType?.rawValue,
                    status:      parsed.status?.rawValue
                )
                let model = ShareViewModel(initial: pending, rawURL: nil)
                rootView = AnyView(ShareView(
                    model: model,
                    onSave: { [weak self] saved in self?.saveAndDismiss(saved) },
                    onCancel: { [weak self] in
                        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                ).preferredColorScheme(scheme))
            } else {
                let model = ShareViewModel(initial: pending, rawURL: rawURL)
                rootView = AnyView(ShareView(
                    model: model,
                    onSave: { [weak self] saved in self?.saveAndDismiss(saved) },
                    onCancel: { [weak self] in
                        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                ).preferredColorScheme(scheme))
            }
            let host = UIHostingController(rootView: rootView)
            host.view.backgroundColor = .clear
            self.addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            ])
            host.didMove(toParent: self)
        }
    }

    // MARK: - Extraction

    @MainActor
    private func extractJobInfo() async -> (SharePendingImport, URL?, String?) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return (SharePendingImport(companyName: "", position: "", sourceURL: nil), nil, nil)
        }

        var foundURL: URL?
        var foundEmailText: String?
        var pageTitle: String?

        for item in items {
            if pageTitle == nil {
                pageTitle = item.attributedTitle?.string ?? item.attributedContentText?.string
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let data = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) {
                        if let url = data as? URL, url.scheme?.hasPrefix("http") == true {
                            foundURL = url
                        } else if let str = data as? String, str.hasPrefix("http"),
                                  let url = URL(string: str) {
                            foundURL = url
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let data = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier),
                       let str = data as? String {
                        if str.hasPrefix("http"), let url = URL(string: str.components(separatedBy: .whitespacesAndNewlines).first ?? "") {
                            foundURL = foundURL ?? url
                        } else if str.contains("\n") || str.count > 200 {
                            foundEmailText = foundEmailText ?? str
                        } else if pageTitle == nil {
                            pageTitle = str
                        }
                    }
                }
            }
        }

        if let emailText = foundEmailText, foundURL == nil {
            return (SharePendingImport(companyName: "", position: ""), nil, emailText)
        } else {
            let parsed = Self.parseJobInfo(title: pageTitle, url: foundURL)
            return (parsed, foundURL, nil)
        }
    }

    // MARK: - URL-based parsing
    // Handles /jobs/view/slug and /comm/jobs/view/slug (tracking variant)

    private static func parseFromURL(_ url: URL) -> (company: String, position: String)? {
        let host = url.host?.lowercased() ?? ""
        guard host.contains("linkedin.com") else { return nil }

        let segments = url.pathComponents
        let slugIndex: Int?
        if segments.count >= 4, segments[1] == "jobs", segments[2] == "view" {
            slugIndex = 3
        } else if segments.count >= 5, segments[2] == "jobs", segments[3] == "view" {
            slugIndex = 4
        } else {
            slugIndex = nil
        }
        guard let idx = slugIndex else { return nil }

        let rawSlug = segments[idx]
        let slug = rawSlug.replacingOccurrences(of: "-\\d+$", with: "", options: .regularExpression)
        guard !slug.isEmpty, !(slug == rawSlug && rawSlug.allSatisfy(\.isNumber)) else { return nil }

        let text = slug.components(separatedBy: "-").filter { !$0.isEmpty }.joined(separator: " ")
        guard let atRange = text.range(of: " at ", options: .caseInsensitive) else { return nil }
        let pos  = String(text[..<atRange.lowerBound]).capitalized
        let comp = String(text[atRange.upperBound...]).capitalized
        guard !pos.isEmpty, !comp.isEmpty else { return nil }
        return (company: comp, position: pos)
    }

    // MARK: - Title-based parsing

    static func parseJobInfo(title: String?, url: URL?) -> SharePendingImport {
        if let url, let parsed = parseFromURL(url) {
            return SharePendingImport(companyName: parsed.company, position: parsed.position, sourceURL: url.absoluteString)
        }

        var company = ""
        var position = ""

        if let raw = title {
            let noise = [
                " | LinkedIn Jobs", " - LinkedIn Jobs",
                " | LinkedIn",      " - LinkedIn",
                " | Indeed",        " - Indeed",
                " | Glassdoor",     " - Glassdoor",
                " | Handshake",     " - Handshake",
                " | Wellfound",     " - Wellfound",
                " | Lever",         " - Lever",
                " | Greenhouse",    " - Greenhouse",
                " | Workday",       " - Workday",
                " | Adzuna",        " - Adzuna",
                " | ZipRecruiter",  " - ZipRecruiter",
                " | Monster",       " - Monster",
                " | CareerBuilder", " - CareerBuilder",
                " | Dice",          " - Dice",
                " | Built In",      " - Built In",
                " | SimplyHired",   " - SimplyHired",
                " Jobs",            " - Jobs",
            ]
            var cleaned = raw
            for n in noise { cleaned = cleaned.replacingOccurrences(of: n, with: "", options: .caseInsensitive) }
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)

            for prefix in ["job application for ", "apply for ", "application for "] {
                if cleaned.lowercased().hasPrefix(prefix) {
                    cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            if let r = cleaned.range(of: " is hiring ", options: .caseInsensitive) {
                company  = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                var pos  = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if pos.lowercased().hasPrefix("a ") || pos.lowercased().hasPrefix("an ") {
                    pos = pos.components(separatedBy: " ").dropFirst().joined(separator: " ")
                }
                position = pos
            } else if let r = cleaned.range(of: " at ", options: .caseInsensitive) {
                position = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                company  = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else if let r = cleaned.range(of: " - ") ?? cleaned.range(of: " – ") {
                position = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                company  = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else if let r = cleaned.range(of: " | ") {
                company  = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                position = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else if !cleaned.isEmpty {
                // Strip "jobs in Location" or "in City, State" suffixes (e.g. Adzuna)
                var pos = cleaned
                if let r = pos.range(of: " jobs in ", options: .caseInsensitive) {
                    pos = String(pos[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                } else if let r = pos.range(of: " in ", options: .caseInsensitive) {
                    let after = String(pos[r.upperBound...])
                    if after.contains(",") || after.contains(";") {
                        pos = String(pos[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                    }
                }
                position = pos.isEmpty ? cleaned : pos
            }
        }

        return SharePendingImport(companyName: company, position: position, sourceURL: url?.absoluteString)
    }

    // MARK: - Save

    private func saveAndDismiss(_ pending: SharePendingImport) {
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults(suiteName: appGroupID)?.set(data, forKey: pendingImportKey)
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

// MARK: - HTML helpers

private func extractMetaContent(from html: String, property: String) -> String? {
    var searchStart = html.startIndex
    while searchStart < html.endIndex {
        guard let metaStart = html.range(of: "<meta", options: .caseInsensitive, range: searchStart..<html.endIndex) else { break }
        guard let tagClose  = html.range(of: ">", range: metaStart.upperBound..<html.endIndex) else { break }
        let tag = String(html[metaStart.lowerBound..<tagClose.upperBound])
        if tag.range(of: property, options: .caseInsensitive) != nil {
            for (open, close) in [("content=\"", "\""), ("content='", "'")] {
                if let cs = tag.range(of: open, options: .caseInsensitive) {
                    let rest = tag[cs.upperBound...]
                    if let ce = rest.firstIndex(of: close.first!) {
                        let value = String(rest[..<ce])
                        if !value.isEmpty { return value }
                    }
                }
            }
        }
        searchStart = tagClose.upperBound
    }
    return nil
}

private func extractHTMLTitle(from html: String) -> String? {
    guard let tagStart = html.range(of: "<title", options: .caseInsensitive),
          let tagEnd   = html[tagStart.lowerBound...].range(of: ">"),
          let closeTag = html[tagEnd.upperBound...].range(of: "</title>", options: .caseInsensitive)
    else { return nil }
    let raw = String(html[tagEnd.upperBound..<closeTag.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return raw.isEmpty ? nil : raw
}

private func htmlDecode(_ str: String) -> String {
    str.replacingOccurrences(of: "&#39;",  with: "'")
       .replacingOccurrences(of: "&#x27;", with: "'")
       .replacingOccurrences(of: "&amp;",  with: "&")
       .replacingOccurrences(of: "&quot;", with: "\"")
       .replacingOccurrences(of: "&lt;",   with: "<")
       .replacingOccurrences(of: "&gt;",   with: ">")
       .replacingOccurrences(of: "&nbsp;", with: " ")
}

// UIImage(named:in:) crashes from extensions — use contentsOfFile instead.
private func loadShareExtensionAppIcon(displayScale: CGFloat) -> UIImage? {
    var appURL = Bundle.main.bundleURL
    for _ in 0..<4 {
        appURL = appURL.deletingLastPathComponent()
        if appURL.pathExtension == "app" { break }
    }
    guard appURL.pathExtension == "app" else { return nil }
    let scale = Int(displayScale)
    let candidates = ["AppIcon60@\(scale)x", "AppIcon60@2x", "AppIcon76@\(scale)x", "AppIcon76@2x", "AppIcon"]
    for name in candidates {
        let path = appURL.appendingPathComponent("\(name).png").path
        if let img = UIImage(contentsOfFile: path) { return img }
    }
    return nil
}

// MARK: - View model

@Observable
private final class ShareViewModel {
    var companyName: String
    var position: String
    let sourceURL: URL?
    var jobType: ShareJobType?   = nil
    var status: ShareJobStatus?  = nil
    var season: ShareJobSeason?  = nil
    var notes: String            = ""

    var logoData: Data?
    var isLogoAutoFetched = false
    var isFetchingTitle   = false
    var isFetchingLogo    = false

    init(initial: SharePendingImport, rawURL: URL?) {
        companyName = initial.companyName
        position    = initial.position
        sourceURL   = rawURL
        jobType     = initial.jobType.flatMap { ShareJobType(rawValue: $0) }
                   ?? Self.detectJobType(from: initial.position)
        status      = initial.status.flatMap { ShareJobStatus(rawValue: $0) }
        season      = initial.season.flatMap { ShareJobSeason(rawValue: $0) }
                   ?? Self.detectSeason(from: initial.position)

        if companyName.isEmpty && position.isEmpty, rawURL != nil {
            isFetchingTitle = true
            Task { await fetchPageTitle(from: rawURL) }
        }
    }

    private static func detectJobType(from position: String) -> ShareJobType? {
        guard !position.isEmpty else { return nil }
        let lower = position.lowercased()

        func hasWord(_ word: String) -> Bool {
            guard let r = lower.range(of: word, options: .caseInsensitive) else { return false }
            let prevOK = r.lowerBound == lower.startIndex || !lower[lower.index(before: r.lowerBound)].isLetter
            let nextOK = r.upperBound == lower.endIndex   || !lower[r.upperBound].isLetter
            return prevOK && nextOK
        }

        if hasWord("internship") || hasWord("intern")          { return .internship }
        if hasWord("co-op") || hasWord("coop") || hasWord("co op") { return .coop }
        if hasWord("part-time") || hasWord("part time")        { return .partTime }
        if hasWord("full-time") || hasWord("full time")        { return .fullTime }
        if hasWord("contract") || hasWord("freelance")         { return .contract }
        if hasWord("temporary") || hasWord("temp")             { return .temporary }
        return nil
    }

    private static func detectSeason(from position: String) -> ShareJobSeason? {
        guard !position.isEmpty else { return nil }
        let lower = position.lowercased()
        func hasWord(_ word: String) -> Bool {
            guard let r = lower.range(of: word, options: .caseInsensitive) else { return false }
            let prevOK = r.lowerBound == lower.startIndex || !lower[lower.index(before: r.lowerBound)].isLetter
            let nextOK = r.upperBound == lower.endIndex   || !lower[r.upperBound].isLetter
            return prevOK && nextOK
        }
        if hasWord("summer")                      { return .summer }
        if hasWord("winter")                      { return .winter }
        if hasWord("spring")                      { return .spring }
        if hasWord("fall") || hasWord("autumn")   { return .fall   }
        return nil
    }

    @MainActor
    func fetchPageTitle(from url: URL?) async {
        defer {
            isFetchingTitle = false
            if jobType == nil { jobType = Self.detectJobType(from: position) }
            if season == nil  { season  = Self.detectSeason(from: position)  }
        }
        guard let url else { return }

        var request = URLRequest(url: url, timeoutInterval: 5)
        // Desktop Chrome UA — more broadly accepted than mobile Safari by job boards
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return }

        // Collect everything useful from the page upfront
        let ogTitle      = extractMetaContent(from: html, property: "og:title").map(htmlDecode)
        let twitterTitle = extractMetaContent(from: html, property: "twitter:title").map(htmlDecode)
        let ogSiteName   = extractMetaContent(from: html, property: "og:site_name").map(htmlDecode)
        let htmlTitle    = extractHTMLTitle(from: html).map(htmlDecode)

        // Prefer candidates that yield both fields; fall back to position-only results
        var partial: SharePendingImport? = nil
        for candidate in [ogTitle, twitterTitle, htmlTitle].compactMap({ $0 }) {
            let parsed = ShareViewController.parseJobInfo(title: candidate, url: url)
            if !parsed.companyName.isEmpty && !parsed.position.isEmpty {
                companyName = parsed.companyName
                position    = parsed.position
                return
            }
            if partial == nil, !parsed.companyName.isEmpty || !parsed.position.isEmpty {
                partial = parsed
            }
        }
        if let p = partial {
            companyName = p.companyName.isEmpty ? (ogSiteName ?? "") : p.companyName
            position    = p.position
            return
        }

        // Last resort: use og:site_name as company if at least the page loaded
        if let siteName = ogSiteName, !siteName.isEmpty {
            companyName = siteName
        }
    }

    @MainActor
    func fetchLogo(for name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let searchURL = URL(string: "https://api.logo.dev/search?q=\(q)") else { return }
        var req = URLRequest(url: searchURL)
        req.setValue("Bearer \(logoSecretKey)", forHTTPHeaderField: "Authorization")

        guard let (sData, _) = try? await URLSession.shared.data(for: req),
              let results    = try? JSONDecoder().decode([LogoResult].self, from: sData),
              let domain     = results.first?.domain, !domain.isEmpty,
              let imgURL     = URL(string: "https://img.logo.dev/\(domain)?token=\(logoPublicKey)&size=128"),
              let (imgData, _) = try? await URLSession.shared.data(from: imgURL),
              !imgData.isEmpty
        else { return }

        logoData = imgData
        isLogoAutoFetched = true
    }
}

private struct LogoResult: Decodable { let domain: String }

// MARK: - Glass card (inline for share extension)

private extension View {
    func shareGlassCard() -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor { trait in
                        trait.userInterfaceStyle == .dark
                            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 0.85)
                            : UIColor.secondarySystemGroupedBackground
                    }))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color(UIColor { trait in
                        trait.userInterfaceStyle == .dark
                            ? UIColor.white.withAlphaComponent(0.08)
                            : UIColor.black.withAlphaComponent(0.04)
                    }), lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

// MARK: - SwiftUI view

private struct ShareView: View {
    @Environment(\.displayScale) private var displayScale
    @State var model: ShareViewModel
    let onSave: (SharePendingImport) -> Void
    let onCancel: () -> Void

    private var canSave: Bool {
        !model.companyName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.position.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            RadialGradient(
                colors: [shareAccent.opacity(0.09), .clear],
                center: UnitPoint(x: 1.2, y: -0.1),
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                handle
                header
                Divider().opacity(0.10)
                ScrollView {
                    VStack(spacing: 16) {
                        if model.isFetchingTitle {
                            scanningBanner
                        }
                        infoSection
                        typePicker
                        statusPicker
                        seasonPicker
                        notesSection
                        if let url = model.sourceURL {
                            urlSection(url)
                        }
                    }
                    .padding()
                    .animation(.easeOut(duration: 0.25), value: model.isFetchingTitle)
                }
                saveButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .padding(.top, 8)
            }
        }
        .task(id: model.companyName) {
            if model.isLogoAutoFetched {
                withAnimation(.easeOut(duration: 0.2)) {
                    model.logoData = nil
                    model.isLogoAutoFetched = false
                }
            }
            guard model.logoData == nil else { return }
            let trimmed = model.companyName.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
            do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { model.isFetchingLogo = true }
            await model.fetchLogo(for: trimmed)
            withAnimation(.easeOut(duration: 0.2)) { model.isFetchingLogo = false }
        }
    }

    // MARK: - Handle & Header

    private var handle: some View {
        Capsule()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 32, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
                    }
            }
            Spacer()
            HStack(spacing: 7) {
                appIconView
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("App Nest")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.primary)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let icon = loadContainerAppIcon() {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
        } else {
            // Mint-green fallback matching the app icon background color
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(red: 0.73, green: 0.97, blue: 0.91))
        }
    }

    private func loadContainerAppIcon() -> UIImage? {
        loadShareExtensionAppIcon(displayScale: displayScale)
    }

    // MARK: - Scanning Banner

    private var scanningBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(.secondary)
            Text("Scanning page for job info…")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shareGlassCard()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Info Section (JobInfoSection style)

    private var infoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(avatarGradient(for: model.companyName))
                    .opacity(model.logoData != nil ? 0 : 1)

                Text(model.companyName.prefix(1).uppercased().isEmpty ? "?" : String(model.companyName.prefix(1).uppercased()))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(model.logoData != nil ? 0 : 1)

                if let data = model.logoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                if model.isFetchingLogo {
                    Circle().fill(.ultraThinMaterial)
                    ProgressView().tint(.white)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.20), radius: 10, y: 5)
            .animation(.easeOut(duration: 0.2), value: model.logoData != nil)
            .animation(.easeOut(duration: 0.2), value: model.isFetchingLogo)
            .overlay(alignment: .bottomTrailing) {
                if model.isFetchingTitle {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color(uiColor: .systemBackground)))
                        .offset(x: 2, y: 2)
                }
            }

            VStack(spacing: 6) {
                TextField("Position Title *", text: Binding(
                    get: { model.position },
                    set: { model.position = $0 }
                ))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                )

                TextField("COMPANY NAME *", text: Binding(
                    get: { model.companyName },
                    set: { model.companyName = $0 }
                ))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.primary.opacity(0.6))
                .textInputAutocapitalization(.words)
                .frame(maxWidth: 220)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                )
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Type Picker

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(icon: "list.bullet", title: "Job Type")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(orderedTypes, id: \.self) { option in
                        sharePill(
                            title: option.rawValue,
                            icon: option.icon,
                            color: option.color,
                            isSelected: model.jobType == option
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                model.jobType = (model.jobType == option ? nil : option)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .shareGlassCard()
    }

    private var orderedTypes: [ShareJobType] {
        guard let sel = model.jobType else { return ShareJobType.allCases }
        return [sel] + ShareJobType.allCases.filter { $0 != sel }
    }

    // MARK: - Status Picker

    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(icon: "rectangle.and.hand.point.up.left.fill", title: "Status")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(orderedStatuses, id: \.self) { option in
                        sharePill(
                            title: option.rawValue,
                            icon: option.icon,
                            color: option.color,
                            isSelected: model.status == option
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                model.status = (model.status == option ? nil : option)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .shareGlassCard()
    }

    private var orderedStatuses: [ShareJobStatus] {
        guard let sel = model.status else { return ShareJobStatus.allCases }
        return [sel] + ShareJobStatus.allCases.filter { $0 != sel }
    }

    // MARK: - Season Picker

    private var seasonPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(icon: "calendar", title: "Season")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShareJobSeason.allCases, id: \.self) { option in
                        sharePill(
                            title: option.rawValue,
                            icon: option.icon,
                            color: option.color,
                            isSelected: model.season == option
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                model.season = (model.season == option ? nil : option)
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .shareGlassCard()
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(icon: "note.text", title: "Notes")

            ZStack(alignment: .topLeading) {
                if model.notes.isEmpty {
                    Text("Add notes about this role…")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.top, 8)
                }
                TextEditor(text: Binding(
                    get: { model.notes },
                    set: { model.notes = $0 }
                ))
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(16)
        .shareGlassCard()
    }

    // MARK: - URL Section

    private func urlSection(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(icon: "link", title: "Job Link")

            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(url.absoluteString)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            )
        }
        .padding(16)
        .shareGlassCard()
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            onSave(SharePendingImport(
                companyName: model.companyName,
                position: model.position,
                sourceURL: model.sourceURL?.absoluteString,
                jobType: model.jobType?.rawValue,
                status: model.status?.rawValue,
                season: model.season?.rawValue,
                notes: model.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : model.notes
            ))
        } label: {
            Text("Add to App Nest")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background {
                    Capsule()
                        .fill(shareAccent.opacity(canSave ? 1.0 : 0.28))
                        .shadow(color: canSave ? shareAccent.opacity(0.32) : .clear, radius: 14, y: 5)
                }
        }
        .disabled(!canSave)
        .animation(.easeOut(duration: 0.18), value: canSave)
    }

    // MARK: - Shared pill & label helpers

    private func sectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.5)
        }
    }

    private func sharePill(
        title: String,
        icon: String,
        color: Color,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: isSelected ? 6 : 5) {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 13 : 12, weight: .bold))
                    .foregroundStyle(isSelected ? .white : color)
                Text(title)
                    .font(.system(size: isSelected ? 14 : 13, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .white : color.opacity(0.88))
            }
            .padding(.horizontal, isSelected ? 14 : 12)
            .padding(.vertical, isSelected ? 9 : 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
                    .overlay(Capsule().strokeBorder(
                        isSelected ? Color.clear : color.opacity(0.28),
                        lineWidth: isSelected ? 0 : 0.8
                    ))
            )
            .shadow(color: isSelected ? color.opacity(0.21) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private func avatarGradient(for name: String) -> LinearGradient {
        let colors: [Color] = [
            Color(red: 0.36, green: 0.66, blue: 0.96),
            Color(red: 0.96, green: 0.73, blue: 0.28),
            Color(red: 0.30, green: 0.80, blue: 0.45),
            Color(red: 0.93, green: 0.38, blue: 0.44),
            Color(red: 0.62, green: 0.52, blue: 0.96),
            Color(red: 0.96, green: 0.52, blue: 0.62),
        ]
        let hash  = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let color = colors[abs(hash) % colors.count]
        return LinearGradient(colors: [color.opacity(0.85), color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

