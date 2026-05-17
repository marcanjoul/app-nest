import Foundation

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
    var notes: String = ""

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

    // Aliases are matched against lowercased, trimmed column headers.
    // Earlier entries win for a given column — order matters for ambiguous overlaps.
    private static let fieldAliases: [(field: String, aliases: [String])] = [
        ("company",      ["company name", "company", "employer", "organization",
                          "company/organization", "firm", "org"]),
        ("position",     ["job title", "position/role", "position", "job role",
                          "posting title", "opening", "title", "role", "job"]),
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
            "yyyy-MM-dd", "MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy",
            "dd/MM/yyyy", "d/M/yyyy", "MMMM d, yyyy", "MMM d, yyyy"
        ].map {
            let df = DateFormatter()
            df.dateFormat = $0
            df.locale = Locale(identifier: "en_US_POSIX")
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
            row.status      = matchStatus(get("status"))
            row.season      = matchSeason(get("season"))
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

    private static func matchStatus(_ raw: String) -> ApplicationStatus? {
        let s = raw.lowercased()
        guard !s.isEmpty else { return nil }
        if let hit = ApplicationStatus.allCases.first(where: { $0.rawValue.lowercased() == s }) { return hit }
        if s.contains("reject") || s.contains("denied") || s.contains("declined") { return .rejected }
        if s.contains("offer")  || s.contains("hired")  || s.contains("accepted") { return .offer }
        if s.contains("interview")                                                  { return .interview }
        if s.contains("applied") || s.contains("submitted") || s.contains("pending") { return .applied }
        if s.contains("apply")  || s.contains("to do") || s.contains("todo") || s.contains("plan") { return .toApply }
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
