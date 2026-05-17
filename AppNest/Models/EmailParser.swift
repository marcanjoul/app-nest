import Foundation
import NaturalLanguage

/// Parses job-related emails to extract application details.
///
/// Uses a hybrid approach:
/// - Pattern matching first (context-aware, high precision for job emails)
/// - Apple's NaturalLanguage NLTagger as fallback for company names
struct EmailParser {

    struct ParsedResult {
        var companyName: String?
        var position: String?
        var jobType: ApplicationType?
        var status: ApplicationStatus?
        var dateApplied: Date?
    }

    func parse(_ emailText: String) -> ParsedResult {
        var result = ParsedResult()
        result.companyName = extractCompanyName(from: emailText)
        result.position    = extractPosition(from: emailText)
        result.jobType     = extractJobType(from: emailText)
        result.status      = extractStatus(from: emailText)
        result.dateApplied = extractDate(from: emailText)
        return result
    }

    // MARK: - Company Name

    private func extractCompanyName(from text: String) -> String? {
        // Strategy 1: Context-aware pattern matching (higher precision in job email context)
        // Patterns ordered from most to least specific.
        let companyPatterns = [
            // "joining BillionToOne" / "join our team at Acme"
            #"(?:joining|join)\s+(?:our\s+team\s+at\s+|the\s+team\s+at\s+)?([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            // "role/position/internship at Company"
            #"(?:role|position|opportunity|internship|job)\s+(?:at|with)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            // "apply/applied/applying to/at Company"
            #"(?:apply|applied|applying)\s+(?:to|at|for)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            // "team/company at/of Company"
            #"(?:team|company)\s+(?:at|of)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            // "welcome to / offer from Company"
            #"(?:welcome to|offer from)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            // "interest in Company" — but NOT "interest in joining" (handled by pattern above)
            #"(?:interest in|interested in)\s+(?!joining\b|applying\b|working\b)([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
        ]

        for pattern in companyPatterns {
            if let result = extractCaptureGroup(from: text, pattern: pattern) {
                var cleaned = result
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))

                let prefixes = ["position ", "role ", "the position ", "the role ", "the "]
                for prefix in prefixes {
                    if cleaned.lowercased().hasPrefix(prefix) {
                        cleaned = String(cleaned.dropFirst(prefix.count))
                    }
                }

                // Strip trailing requisition IDs (e.g. "Acme - 30788")
                if let idRange = cleaned.range(of: #"\s*-\s*\d{4,}$"#, options: .regularExpression) {
                    cleaned = String(cleaned[..<idRange.lowerBound])
                }

                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count < 100 {
                    return cleaned
                }
            }
        }

        // Strategy 2: NLTagger NER (broader coverage, filtered for job-platform noise)
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var organizations: [String: Int] = [:]
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, tokenRange in
            if tag == .organizationName {
                let name = String(text[tokenRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { organizations[name, default: 0] += 1 }
            }
            return true
        }

        // Remove job platforms and social networks that appear in email boilerplate
        let boilerplateOrgs: Set<String> = [
            "LinkedIn", "Indeed", "Glassdoor", "Handshake",
            "ZipRecruiter", "Monster", "CareerBuilder", "Wellfound"
        ]
        let filtered = organizations.filter { !boilerplateOrgs.contains($0.key) }

        return filtered.sorted(by: { $0.value > $1.value }).first?.key
    }

    // MARK: - Position Title

    private func extractPosition(from text: String) -> String? {
        let patterns = [
            // "applying for the Intern, Software Engineer position at Company" — full title before "position/role at"
            #"(?:application|applied|applying)\s+(?:for|to)\s+(?:the\s+)?(.+?)\s+(?:position|role)\s+(?:at|with|@)"#,
            // "application/applied/applying for/to [POSITION] at Company"
            #"(?:application|applied|applying)\s+(?:for|to)\s+(?:the\s+)?(.+?)(?:\s+(?:at|with|@)\s+|,|\.\s|\n|$)"#,
            // "vacancy/opening for [the/our/a] [POSITION] role/position"
            // e.g. "filled the vacancy for our AI Engineering Intern position"
            #"(?:vacancy|opening)\s+for\s+(?:the\s+|our\s+|a\s+|an\s+)?(.+?)\s+(?:role|position)"#,
            // "interview[ing] for [the] [POSITION]"
            #"interview(?:ing)?\s+(?:you\s+)?for\s+(?:the\s+)?(.+?)(?:\s+(?:at|with|@)\s+|,|\.\s|\n|$)"#,
            // "role/position of [POSITION]"
            #"(?:role|position)\s+of\s+(?:the\s+)?(.+?)(?:\s+(?:at|with|@)\s+|,|\.\s|\n|$)"#,
            // "offer you [the] [POSITION] role/position"
            #"offer\s+(?:you\s+)?(?:the\s+)?(.+?)\s+(?:role|position)"#,
            // "the/our [POSITION] role/position" — skip non-title nouns like "vacancy", "opening", "job", "posting"
            #"(?:the|our)\s+(?!vacancy\b|opening\b|job\b|posting\b)(.+?)\s+(?:role|position|opening|opportunity)"#,
            // Label-style "Role: X" / "Position: X"
            #"(?:role|position|title)\s*:\s*(.+?)(?:\n|$)"#,
            // "as a/an [POSITION]"
            #"as\s+(?:a|an)\s+(.+?)(?:\.|,|\n|$)"#,
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(text[match])
                if let raw = extractCaptureGroup(from: matched, pattern: pattern) {
                    let cleaned = cleanupPosition(raw)
                    if !cleaned.isEmpty && cleaned.count < 100 {
                        return cleaned
                    }
                }
            }
        }

        return nil
    }

    private func cleanupPosition(_ raw: String) -> String {
        var s = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))

        // Strip leading noise that may have leaked into the capture group
        let leadingNoise = ["role of the ", "position of the ", "role of ", "position of ",
                            "the ", "our ", "a ", "an "]
        for noise in leadingNoise {
            if s.lowercased().hasPrefix(noise) {
                s = String(s.dropFirst(noise.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Strip trailing "role"/"position" if it leaked in (e.g. from interview-for pattern)
        let trailingSuffixes = [" role", " position"]
        for suffix in trailingSuffixes {
            if s.lowercased().hasSuffix(suffix) {
                s = String(s.dropLast(suffix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return s
    }

    // MARK: - Job Type

    private func extractJobType(from text: String) -> ApplicationType? {
        let lowered = text.lowercased()

        // Ordered by specificity — check co-op before "contract" to avoid false positives
        let typePatterns: [(ApplicationType, [String])] = [
            (.internship, ["intern ", "internship", " intern\n", " intern,", " intern."]),
            (.Co_op,      ["co-op", "co op", "coop"]),
            (.partTime,   ["part-time", "part time"]),
            (.fullTime,   ["full-time", "full time"]),
            (.contract,   ["contract position", "contract role", "contractor"]),
            (.temporary,  ["temporary position", "temporary role", "temp position"]),
        ]

        for (type, keywords) in typePatterns {
            for keyword in keywords {
                if lowered.contains(keyword) {
                    return type
                }
            }
        }

        // Fallback: check if position title already contains a type hint
        let positionText = extractPosition(from: text)?.lowercased() ?? ""
        if positionText.contains("intern") { return .internship }
        if positionText.contains("co-op") || positionText.contains("coop") { return .Co_op }

        return nil
    }

    // MARK: - Status

    private func extractStatus(from text: String) -> ApplicationStatus? {
        let lowered = text.lowercased()

        let conditionalPrefixes = ["if you are ", "if you're ", "in case you ", "should you "]

        let statusPatterns: [(ApplicationStatus, [String])] = [
            (.offer, [
                "pleased to offer", "we'd like to offer", "offer letter",
                "we are excited to offer", "officially offer", "happy to offer",
                "extend an offer", "welcome to the team"
            ]),
            (.rejected, [
                "unfortunately", "not moving forward", "will not be moving",
                "decided not to", "other candidates", "filled the vacancy",
                "regret to inform", "unable to offer", "wish you the best",
                "after careful consideration", "position has been filled",
                "no longer considering", "we will not be"
            ]),
            (.interview, [
                "schedule an interview", "interview invitation", "like to interview",
                "next round", "phone screen", "technical interview",
                "would like to speak", "meet with our team", "interview with",
                "advance to", "moving you forward", "selected for an interview",
                "invite you to interview", "congratulations"
            ]),
            (.applied, [
                "thank you for applying", "application received",
                "application has been submitted", "successfully submitted",
                "we have received your application", "thank you for your interest",
                "confirm your application", "received your application",
                "reviewing your application", "we received your application"
            ]),
        ]

        for (status, phrases) in statusPatterns {
            for phrase in phrases {
                if lowered.contains(phrase) {
                    if status == .rejected {
                        let isConditional = conditionalPrefixes.contains { conditional in
                            if let condRange  = lowered.range(of: conditional),
                               let phraseRange = lowered.range(of: phrase) {
                                let sentenceStart = lowered[..<phraseRange.lowerBound]
                                    .lastIndex(of: ".") ?? lowered.startIndex
                                return condRange.lowerBound >= sentenceStart
                                    && condRange.lowerBound < phraseRange.lowerBound
                            }
                            return false
                        }
                        if isConditional { continue }
                    }
                    return status
                }
            }
        }

        return .applied
    }

    // MARK: - Date (NSDataDetector)

    private func extractDate(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector?.matches(in: text, options: [], range: range) ?? []

        let now = Date()
        let sixMonthsAgo  = Calendar.current.date(byAdding: .month, value: -6, to: now)!
        let oneMonthAhead = Calendar.current.date(byAdding: .month, value:  1, to: now)!

        for match in matches {
            if let date = match.date, date >= sixMonthsAgo && date <= oneMonthAhead {
                return date
            }
        }

        return Date()
    }

    // MARK: - Helpers

    private func extractCaptureGroup(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }
}
