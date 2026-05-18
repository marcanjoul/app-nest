import Foundation
import NaturalLanguage

// MARK: - Highlight types (used by EmailParserView to colour matched spans)

enum HighlightField { case company, position, status, date }

struct HighlightSpan {
    let text:  String
    let field: HighlightField
}

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
        var highlights: [HighlightSpan] = []
    }

    func parse(_ emailText: String) -> ParsedResult {
        var result = ParsedResult()
        result.companyName = extractCompanyName(from: emailText)
        result.position    = extractPosition(from: emailText)
        result.jobType     = extractJobType(from: emailText)

        let (status, statusPhrase) = extractStatusAndPhrase(from: emailText)
        result.status = status

        let (date, dateText) = extractDateAndText(from: emailText)
        result.dateApplied = date

        if let v = result.companyName, !v.isEmpty  { result.highlights.append(.init(text: v,      field: .company)) }
        if let v = result.position,    !v.isEmpty  { result.highlights.append(.init(text: v,      field: .position)) }
        if let p = statusPhrase                    { result.highlights.append(.init(text: p,      field: .status)) }
        if let d = dateText,           !d.isEmpty  { result.highlights.append(.init(text: d,      field: .date)) }

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
            // "applied to [POSITION] at Company" — skip past the position title to find the company
            #"(?:apply|applied|applying)\s+(?:to|for)\s+.+?\s+at\s+([A-Z][A-Za-z0-9&®\s\.]+?)(?:\s+on\b|\s+via\b|\s+through\b|\.|,|\!|\n|$)"#,
            // "apply/applied/applying to/at Company" — negative lookahead skips articles that precede position titles
            #"(?:apply|applied|applying)\s+(?:to|at|for)\s+(?!the\b|a\b|an\b)([A-Z][A-Za-z0-9&\s\.]+?)(?:\s+through\b|\s+via\b|\.|,|\!|\n|$)"#,
            // "application to Company" — acknowledgment emails ("submit an application to Snackpass")
            #"(?:application|applying|applied)\s+to\s+([A-Z][A-Za-z0-9&\.]+(?:\s+[A-Z][A-Za-z0-9&\.]+){0,2})(?:'s)?\b"#,
            // "about Company and" — rejection emails ("learn more about Intuitive and the...")
            #"about\s+([A-Z][A-Za-z0-9&\.]+)\s+and\b"#,
            // "part of Company" — excitement/acknowledgment emails ("be a part of Okta's momentum")
            #"(?:part\s+of|be\s+part\s+of)\s+([A-Z][A-Za-z0-9&\.]+)(?:'s)?\b"#,
            // "here at Company" / "on behalf of Company" — recruiter outreach
            #"(?:here\s+at|team\s+at|staff\s+at)\s+([A-Z][A-Za-z0-9&\.]+(?:\s+[A-Z][A-Za-z0-9&\.]+){0,2})\b"#,
            #"on\s+behalf\s+of\s+([A-Z][A-Za-z0-9&\.]+(?:\s+[A-Z][A-Za-z0-9&\.]+){0,2})(?:'s)?\b"#,
            // "Company is committed/growing/excited..." — company self-describes ("Helios Medical is committed to...")
            #"([A-Z][A-Za-z0-9&]+(?:\s+[A-Z][A-Za-z0-9&]+){0,2})\s+is\s+(?:committed|growing|excited|dedicated|building|expanding|a\s+fast|at\s+a)\b"#,
            // "team/company at/of Company"
            #"(?:team|company)\s+(?:at|of)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            // "welcome to / offer from Company"
            #"(?:welcome to|offer from)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            // "interest in Company" — but NOT "interest in joining" (handled by pattern above)
            #"(?:interest in|interested in)\s+(?!joining\b|applying\b|working\b)([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
        ]

        for pattern in companyPatterns {
            if let result = extractCaptureGroup(from: text, pattern: pattern) {
                // Company names are proper nouns — the raw capture must start uppercase.
                // NSRegularExpression with .caseInsensitive makes [A-Z] match lowercase,
                // so without this guard common words like "our", "the", "understanding" slip through.
                guard result.first?.isUppercase == true else { continue }

                var cleaned = result
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:®™"))

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

                // Strip "a <noun> at <Company>" / "an <noun> at <Company>" — the regex engine's
                // caseInsensitive flag makes [A-Z] match lowercase, so "interest in a career at Microsoft"
                // captures "a career at Microsoft" instead of just "Microsoft".
                if let m = cleaned.range(of: #"^(?:a|an)\s+\w+\s+at\s+"#, options: [.regularExpression, .caseInsensitive]) {
                    cleaned = String(cleaned[m.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
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
        // NLTagger sometimes mis-tags job titles (e.g. "Data Science Internship") as org names.
        // Reject any tagged entity whose text contains position-type keywords.
        let positionKeywords = ["internship", "intern", "engineer", "developer", "manager",
                                "analyst", "designer", "scientist", "researcher", "coordinator",
                                "associate", "director", "co-op", "specialist", "consultant"]
        let filtered = organizations.filter { org in
            let lower = org.key.lowercased()
            return !boilerplateOrgs.contains(org.key)
                && !positionKeywords.contains(where: { lower.contains($0) })
        }

        return filtered.sorted(by: { $0.value > $1.value }).first?.key
    }

    // MARK: - Position Title

    private func extractPosition(from text: String) -> String? {
        let patterns = [
            // "application/applied for Data Science Intern." — title ends sentence with no trailing keyword
            #"(?:application|applied|applying)\s+for\s+(?:the\s+)?(.+?)(?:\s+(?:position|role)\b|\s+(?:at|with|@)\s+|[.,\n]|$)"#,
            // "apply/application/applied/applying for the AI Engineering Intern position" — title ends at "position/role"
            #"(?:\bapply\b|application|applied|applying)\s+(?:for|to)\s+(?:the\s+)?(.+?)\s+(?:position|role)\b"#,
            // "application/applied/applying for [POSITION] at Company" — requires company context
            #"(?:application|applied|applying)\s+for\s+(?:the\s+)?(.+?)\s+(?:at|with|@)\s+"#,
            // "vacancy/opening for [the/our/a] [POSITION] role/position"
            #"(?:vacancy|opening)\s+for\s+(?:the\s+|our\s+|a\s+|an\s+)?(.+?)\s+(?:role|position)"#,
            // "interviewing you for [the] [POSITION]"
            #"interview(?:ing)?\s+you\s+for\s+(?:the\s+)?(.+?)(?:\s+(?:at|with|@)\s+|,|\.\s|\n|$)"#,
            // "role/position of [POSITION]"
            #"(?:role|position)\s+of\s+(?:the\s+)?(.+?)(?:\s+(?:at|with|@)\s+|,|\.\s|\n|$)"#,
            // "offer you [the] [POSITION] role/position"
            #"offer\s+(?:you\s+)?(?:the\s+)?(.+?)\s+(?:role|position)"#,
            // "the/our [POSITION] role/position"
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
                    let cleaned = cleanupPosition(cleaned: raw)
                    if !cleaned.isEmpty && cleaned.count < 100 {
                        return cleaned
                    }
                }
            }
        }

        return nil
    }

    private func cleanupPosition(cleaned raw: String) -> String {
        var s = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))

        // Strip leading noise
        let leadingNoise = ["role of the ", "position of the ", "role of ", "position of ",
                            "for the ", "for a ", "for an ",
                            "the ", "our ", "a ", "an "]
        for noise in leadingNoise {
            if s.lowercased().hasPrefix(noise) {
                s = String(s.dropFirst(noise.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Strip trailing "role"/"position"
        let trailingSuffixes = [" role", " position"]
        for suffix in trailingSuffixes {
            if s.lowercased().hasSuffix(suffix) {
                s = String(s.dropLast(suffix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Strip job requisition IDs (e.g. "(JOB212131)", "(REQ-4892)", or standing alone like "R160469")
        let idPatterns = [
            #"\s*\([A-Z]{2,}[-]?\d+\)"#,      // (REQ-123)
            #"^[A-Z]\d{5,}\s+"#,              // R160469 at start
            #"\s+-\s+[A-Z]\d{5,}"#,           // - R160469 at end
            #"^\d{4,}\s+"#                    // 2026 or similar years/IDs at start
        ]
        
        for pattern in idPatterns {
            if let range = s.range(of: pattern, options: .regularExpression) {
                if pattern.hasPrefix("^") {
                    s = String(s[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    s = String(s[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
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

    private func extractStatusAndPhrase(from text: String) -> (ApplicationStatus, String?) {
        let lowered = text.lowercased()

        let conditionalPrefixes = ["if you are ", "if you're ", "in case you ", "should you "]

        let statusPatterns: [(ApplicationStatus, [String])] = [
            (.offer, [
                "pleased to offer", "we'd like to offer", "offer letter",
                "we are excited to offer", "officially offer", "happy to offer",
                "extend an offer", "extended an offer", "welcome to the team",
                "welcome aboard", "offer package", "you have been selected for the"
            ]),
            (.rejected, [
                "unfortunately", "not moving forward", "will not be moving",
                "decided not to", "other candidates", "filled the vacancy",
                "regret to inform", "unable to offer", "wish you the best",
                "after careful consideration", "position has been filled",
                "no longer considering", "we will not be",
                "not advancing", "not be advancing", "not been selected",
                "have not been selected", "not selected to", "not able to move forward",
                "not able to offer", "unable to move forward"
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
                "reviewing your application", "we received your application",
                "successfully applied"
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
                    // "phone screen", "technical interview" etc. appearing in a process
                    // description ("our process involves a phone screen") are not status signals.
                    if status == .interview {
                        let processDescriptionPhrases = [
                            "process includes", "process involves",
                            "stages include", "stages involving", "stages including",
                            "typically involves", "typically includes",
                            "steps include", "steps are"
                        ]
                        let isProcessDescription = processDescriptionPhrases.contains { desc in
                            guard let descRange   = lowered.range(of: desc),
                                  let phraseRange = lowered.range(of: phrase) else { return false }
                            let sentenceStart: String.Index
                            if let dot = lowered[..<phraseRange.lowerBound].lastIndex(of: ".") {
                                sentenceStart = lowered.index(after: dot)
                            } else {
                                sentenceStart = lowered.startIndex
                            }
                            return descRange.lowerBound >= sentenceStart
                                && descRange.upperBound <= phraseRange.lowerBound
                        }
                        if isProcessDescription { continue }
                    }
                    return (status, phrase)
                }
            }
        }

        return (.applied, nil)
    }

    // MARK: - Date (NSDataDetector)

    private func extractDateAndText(from text: String) -> (Date?, String?) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return (Date(), nil)
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: nsRange)

        let now = Date()
        let twoYearsAgo   = Calendar.current.date(byAdding: .year, value: -2, to: now)!
        let twoYearsAhead = Calendar.current.date(byAdding: .year, value:  2, to: now)!

        for match in matches {
            guard let date = match.date,
                  date >= twoYearsAgo && date <= twoYearsAhead else { continue }
            let dateText = Range(match.range, in: text).map { String(text[$0]) }
            return (date, dateText)
        }

        return (Date(), nil)
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
