import Foundation
import NaturalLanguage

// MARK: - Import Row

struct CSVImportRow: Identifiable {
    var id = UUID()
    var companyName: String = ""
    var position: String = ""
    var jobType: ApplicationType? = nil
    var status: ApplicationStatus? = nil
    var season: ApplicationSeason? = nil
    var dateApplied: Date = Date()
    var compensationAmount: Double? = nil
    var compensationKind: CompensationKind? = nil
    var compensationCurrency: Currency? = .usd
    var salaryPeriod: SalaryPeriod? = .yearly
    var workMode: WorkMode? = nil
    var location: String = ""
    var jobURL: String = ""
    var notes: String = ""
    var cycleID: UUID? = nil
    var logoData: Data? = nil

    var missingFields: [String] {
        var f: [String] = []
        if companyName.trimmingCharacters(in: .whitespaces).isEmpty { f.append("Company") }
        if position.trimmingCharacters(in: .whitespaces).isEmpty    { f.append("Position") }
        if jobType == nil                                            { f.append("Type") }
        if status  == nil                                            { f.append("Status") }
        return f
    }
    var isComplete: Bool { missingFields.isEmpty }
}

// MARK: - Parser

enum CSVImporter {

    // Semantic anchor phrases used by NLEmbedding for fuzzy header matching.
    // Each field lists diverse natural-language variants — the closer a CSV header
    // is to any anchor (cosine distance), the more confidently it maps to that field.
    private static let fieldSemanticAnchors: [(field: String, anchors: [String])] = [
        ("company",      ["company name", "employer", "organization", "company", "firm"]),
        ("position",     ["position title", "job title", "role", "job role", "opening", "title"]),
        ("type",         ["job type", "employment type", "work type", "contract type", "position type"]),
        ("status",       ["application status", "status", "stage", "outcome", "hiring stage"]),
        ("season",       ["season", "term", "semester", "cohort", "cycle term"]),
        ("date",         ["application date", "date applied", "applied date", "submission date", "apply date"]),
        ("compensation", ["salary", "compensation", "pay rate", "stipend", "base pay", "wage"]),
        ("currency",     ["currency", "currency code", "pay currency"]),
        ("notes",        ["notes", "comments", "additional notes", "remarks", "description"]),
        ("url",          ["job url", "job link", "application url", "posting url", "listing url", "apply link"]),
        ("work_mode",    ["work mode", "remote or onsite", "work arrangement", "work type", "remote status"]),
        ("location",     ["location", "city", "office location", "work location", "job location"]),
    ]

    // Kept as a fallback for when the NLEmbedding model is unavailable on-device.
    private static let fieldAliases: [(field: String, aliases: [String])] = [
        ("company",      ["company name", "company", "employer", "organization",
                          "company/organization", "firm", "org"]),
        ("position",     ["job title", "position/role", "position", "job role",
                          "posting title", "opening", "title", "role", "job", "name"]),
        ("type",         ["employment type", "job type", "contract type", "job category",
                          "work type", "position type", "employment", "type"]),
        ("status",       ["application status", "hiring stage", "hiring status",
                          "stage", "state", "outcome", "progress", "result", "status"]),
        ("season",       ["start season", "cycle term", "season", "cohort",
                          "semester", "intake", "term"]),
        ("date",         ["date applied", "applied date", "application date",
                          "submission date", "date submitted", "submitted on",
                          "applied on", "apply date", "submitted", "date"]),
        ("compensation", ["base salary", "base pay", "salary/compensation",
                          "compensation", "stipend", "pay rate", "salary",
                          "wage", "rate", "pay", "comp"]),
        ("currency",     ["currency code", "pay currency", "pay in", "currency", "curr"]),
        ("notes",        ["additional notes", "extra notes", "job notes",
                          "comments", "description", "remarks", "memo", "note", "notes"]),
        ("url",          ["job url", "job link", "application url", "posting url",
                          "listing url", "apply link", "apply url", "link", "url"]),
        ("work_mode",    ["work mode", "work arrangement", "remote status", "work type",
                          "remote or onsite", "location type", "remote"]),
        ("location",     ["location", "city", "office", "work location",
                          "job location", "office location", "place"]),
    ]

    // MARK: - Public API

    static func parse(_ raw: String) -> [CSVImportRow] {
        var text = raw
        // Strip UTF-8 BOM
        if text.hasPrefix("\u{FEFF}") { text = String(text.dropFirst()) }

        var lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
        while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeLast() }
        guard lines.count > 1 else { return [] }

        let headers = parseLine(lines[0]).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let colMap  = buildColumnMap(from: headers)

        let dateParsers: [DateFormatter] = [
            "d-MMM-yy", "dd-MMM-yy", "d-MMM-yyyy", "dd-MMM-yyyy",
            "yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy",
            "dd/MM/yyyy", "d/M/yyyy", "MMMM d, yyyy", "MMM d, yyyy"
        ].map {
            let df = DateFormatter()
            df.dateFormat = $0
            df.locale = Locale(identifier: "en_US_POSIX")
            df.isLenient = false
            return df
        }

        return lines.dropFirst().compactMap { line -> CSVImportRow? in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let fields = parseLine(line)

            func get(_ key: String) -> String {
                guard let idx = colMap[key], idx < fields.count else { return "" }
                return fields[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var row = CSVImportRow()
            row.companyName = get("company")
            row.position    = get("position")
            row.jobType     = matchType(get("type"))
            if row.jobType == nil {
                row.jobType = matchTypeFromTitle(row.position)
            }
            row.status      = matchStatus(get("status"))
            row.season      = matchSeason(get("season"))
            row.workMode    = matchWorkMode(get("work_mode"))
            row.location    = get("location")
            row.jobURL      = get("url")
            row.notes       = get("notes")

            let dateStr = get("date")
            if !dateStr.isEmpty {
                row.dateApplied = dateParsers.compactMap { $0.date(from: dateStr) }.first ?? Date()
            }

            parseCompensation(comp: get("compensation"), curr: get("currency"), into: &row)
            return row
        }
    }

    // MARK: - RFC 4180 line parser

    static func parseLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    }
                    inQuotes = false
                } else {
                    current.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",":  result.append(current); current = ""
                default:   current.append(c)
                }
            }
            i = line.index(after: i)
        }
        result.append(current)
        return result
    }

    // MARK: - Column mapping

    private static func buildColumnMap(from headers: [String]) -> [String: Int] {
        if let map = buildColumnMapWithEmbedding(from: headers), !map.isEmpty {
            return map
        }
        return buildColumnMapWithAliases(from: headers)
    }

    // NLP-based: uses NLEmbedding.sentenceEmbedding to semantically match each header
    // against anchor phrases. Greedy assignment picks lowest-distance (field, column) pairs.
    private static func buildColumnMapWithEmbedding(from headers: [String]) -> [String: Int]? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }

        struct Candidate { let idx: Int; let field: String; let distance: NLDistance }
        var candidates: [Candidate] = []

        for (idx, header) in headers.enumerated() {
            let normalized = header.lowercased().trimmingCharacters(in: .whitespaces)
            for (field, anchors) in fieldSemanticAnchors {
                let best = anchors
                    .map { embedding.distance(between: normalized, and: $0) }
                    .min() ?? 1.0
                candidates.append(Candidate(idx: idx, field: field, distance: best))
            }
        }

        // Greedy: assign the most confident (lowest distance) pairs first,
        // ensuring each column index and each field is used at most once.
        let sorted = candidates.sorted { $0.distance < $1.distance }
        var map: [String: Int] = [:]
        var usedIdx   = Set<Int>()
        var usedField = Set<String>()

        for c in sorted {
            guard !usedIdx.contains(c.idx),
                  !usedField.contains(c.field),
                  c.distance < 0.65 else { continue }
            map[c.field] = c.idx
            usedIdx.insert(c.idx)
            usedField.insert(c.field)
        }

        return map
    }

    // Alias-based fallback: exact-match or substring against the hardcoded alias table.
    private static func buildColumnMapWithAliases(from headers: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (idx, header) in headers.enumerated() {
            for (field, aliases) in fieldAliases {
                guard map[field] == nil else { continue }
                if aliases.contains(where: { header == $0 || header.contains($0) }) {
                    map[field] = idx
                }
            }
        }
        return map
    }

    // MARK: - Field matchers

    private static func matchType(_ raw: String) -> ApplicationType? {
        let s = raw.lowercased()
        guard !s.isEmpty else { return nil }
        if let hit = ApplicationType.allCases.first(where: { $0.rawValue.lowercased() == s }) { return hit }
        if s.contains("intern")   { return .internship }
        if s.contains("co-op") || s.contains("coop") { return .Co_op }
        if s.contains("part")     { return .partTime }
        if s.contains("full")     { return .fullTime }
        if s.contains("contract") { return .contract }
        if s.contains("temp")     { return .temporary }
        return nil
    }

    private static func matchTypeFromTitle(_ raw: String) -> ApplicationType? {
        let s = raw.lowercased()
        guard !s.isEmpty else { return nil }

        let typePatterns: [(ApplicationType, [String])] = [
            (.Co_op,      ["co-op", "co op", "coop"]),
            (.partTime,   ["part-time", "part time"]),
            (.fullTime,   ["full-time", "full time"]),
            (.contract,   ["contract position", "contract role", "contractor"]),
            (.temporary,  ["temporary position", "temporary role", "temp position"]),
        ]

        if s.range(of: #"\bintern(?:ship|ships|s)?\b"#, options: .regularExpression) != nil {
            return .internship
        }

        for (type, keywords) in typePatterns {
            for keyword in keywords where s.contains(keyword) {
                return type
            }
        }

        return nil
    }

    private static func matchStatus(_ raw: String) -> ApplicationStatus? {
        let s = raw.lowercased()
        guard !s.isEmpty else { return nil }
        if let hit = ApplicationStatus.allCases.first(where: { $0.rawValue.lowercased() == s }) { return hit }
        if s.contains("reject") || s.contains("denied") || s.contains("declined") { return .rejected }
        if s.contains("offer")  || s.contains("hired")  || s.contains("accepted") { return .offer }
        if s.contains("interview")                                                  { return .interview }
        if s.contains("applied") || s.contains("submitted") || s.contains("pending") { return .applied }
        if s.contains("apply")  || s.contains("to do") || s.contains("todo") || s.contains("plan") { return .toApply }
        if s.contains("ghost")                                                      { return .ghosted }
        if s.contains("removed") || s.contains("expired") || s.contains("closed") || s.contains("filled") { return .jobRemoved }
        return nil
    }

    private static func matchWorkMode(_ raw: String) -> WorkMode? {
        let s = raw.lowercased()
        guard !s.isEmpty else { return nil }
        if let hit = WorkMode.allCases.first(where: { $0.rawValue.lowercased() == s }) { return hit }
        if s.contains("remote") { return .remote }
        if s.contains("hybrid") { return .hybrid }
        if s.contains("on-site") || s.contains("onsite") || s.contains("in-office") || s.contains("in person") || s.contains("office") { return .onSite }
        return nil
    }

    private static func matchSeason(_ raw: String) -> ApplicationSeason? {
        let s = raw.lowercased()
        guard !s.isEmpty else { return nil }
        if let hit = ApplicationSeason.allCases.first(where: { $0.rawValue.lowercased() == s }) { return hit }
        if s.contains("winter")                    { return .winter }
        if s.contains("spring")                    { return .spring }
        if s.contains("summer")                    { return .summer }
        if s.contains("fall") || s.contains("autumn") { return .fall }
        return nil
    }

    private static func parseCompensation(comp: String, curr: String, into row: inout CSVImportRow) {
        guard !comp.isEmpty else { return }
        let cleaned = comp
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .trimmingCharacters(in: .whitespaces)

        // Extract the leading number token
        let firstToken = cleaned.components(separatedBy: .whitespaces).first ?? ""
        var numStr = firstToken
        let isK = numStr.lowercased().hasSuffix("k")
        if isK { numStr = String(numStr.dropLast()) }
        guard var amount = Double(numStr) else { return }
        if isK { amount *= 1_000 }

        row.compensationAmount   = amount
        let lower                = comp.lowercased()
        row.compensationKind     = lower.contains("hour") ? .hourly : .salary
        row.salaryPeriod         = lower.contains("month") ? .monthly : .yearly

        let currLower = curr.lowercased().trimmingCharacters(in: .whitespaces)
        row.compensationCurrency = Currency.allCases.first(where: { $0.rawValue.lowercased() == currLower }) ?? .usd
    }
}
