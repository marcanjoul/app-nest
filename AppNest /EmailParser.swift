//
//  EmailParser.swift
//  AppNest
//
//  Created by Mark Anjoul on 3/17/26.
//


import Foundation
import NaturalLanguage

/// Parses job-related emails to extract application details.
///
/// Uses a hybrid approach:
/// - Apple's NaturalLanguage framework (NLTagger) for company name extraction
/// - Pattern matching for position titles, dates, and status keywords
struct EmailParser {
    
    struct ParsedResult {
        var companyName: String?
        var position: String?
        var status: ApplicationStatus?
        var dateApplied: Date?
    }
    
    /// Main entry point — takes raw email text and returns extracted fields.
    func parse(_ emailText: String) -> ParsedResult {
        var result = ParsedResult()
        
        result.companyName = extractCompanyName(from: emailText)
        result.position = extractPosition(from: emailText)
        result.status = extractStatus(from: emailText)
        result.dateApplied = extractDate(from: emailText)
        
        return result
    }
    
    // MARK: - Company Name (NLTagger)
    
    /// Uses Apple's on-device NER to find organization names in the text.
    /// If multiple organizations are found, picks the most frequently mentioned one.
    private func extractCompanyName(from text: String) -> String? {
        // Strategy 1: NLTagger NER
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
                if !name.isEmpty {
                    organizations[name, default: 0] += 1
                }
            }
            return true
        }
        
        if let topOrg = organizations.sorted(by: { $0.value > $1.value }).first?.key {
            return topOrg
        }
        
        // Strategy 2: Pattern matching fallback
        let companyPatterns = [
            #"(?:interest in|interested in)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            #"(?:apply|applied|applying)\s+(?:to|at|for)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\n|$)"#,
            #"(?:joining|join)\s+(?:our\s+team\s+at\s+|the\s+team\s+at\s+|)([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\n|$)"#,
            #"(?:team|company)\s+(?:at|of)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\n|$)"#,
            #"(?:welcome to|offer from)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\!|\n|$)"#,
            #"(?:position|role|opportunity)\s+(?:at|with)\s+([A-Z][A-Za-z0-9&\s\.]+?)(?:\.|,|\n|$)"#,
        ]
        
        for pattern in companyPatterns {
            if let result = extractCaptureGroup(from: text, pattern: pattern) {
                var cleaned = result
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                
                // Remove leading "position"/"role" if it leaked in
                let prefixes = ["position ", "role ", "the position ", "the role "]
                for prefix in prefixes {
                    if cleaned.lowercased().hasPrefix(prefix) {
                        cleaned = String(cleaned.dropFirst(prefix.count))
                    }
                }
                
                // Remove trailing requisition/job ID numbers (e.g. "- 3078849")
                if let idRange = cleaned.range(of: #"\s*-\s*\d{4,}$"#, options: .regularExpression) {
                    cleaned = String(cleaned[..<idRange.lowerBound])
                }
                
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleaned.isEmpty && cleaned.count < 100 {
                    return cleaned
                }
            }

        }
        
        return nil
    }
    
    // MARK: - Position Title (Pattern Matching)
    
    /// Looks for common email patterns like:
    /// "your application for [POSITION]"
    /// "the [POSITION] role/position"
    /// "applying for [POSITION]"
    /// "applied to [POSITION]"
    private func extractPosition(from text: String) -> String? {
        let patterns = [
            // "application/applied/applying for/to [POSITION] at/with/for/@ Company"
            #"(?:application|applied|applying)\s+(?:for|to)\s+(?:the\s+)?(.+?)(?:\s+(?:at|with|for|@)\s+|,|\.\s|\n|$)"#,
            // "the Software Engineer role/position"
            #"(?:the|our)\s+(.+?)\s+(?:role|position|opening|opportunity)"#,
            // "Role: Software Engineer" or "Position: Software Engineer"
            #"(?:role|position|title)\s*:\s*(.+?)(?:\n|$)"#,
            // "interviewing for Software Engineer"
            #"interviewing\s+(?:you\s+)?for\s+(?:the\s+)?(.+?)(?:\s+(?:at|with|for|@)\s+|,|\.\s|\n|$)"#,
            // "offer you the Mobile Engineer role"
            #"offer\s+(?:you\s+)?(?:the\s+)?(.+?)\s+(?:role|position)"#,
            // "interest in the [POSITION]" or "interest in joining ... as a [POSITION]"
            #"as\s+(?:a|an)\s+(.+?)(?:\.|,|\n|$)"#,
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(text[match])
                if let result = extractCaptureGroup(from: matched, pattern: pattern) {
                    let cleaned = result
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                    if !cleaned.isEmpty && cleaned.count < 100 {
                        return cleaned
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Status (Keyword Matching)
    
    /// Detects application status from common email phrases.
    private func extractStatus(from text: String) -> ApplicationStatus? {
        let lowered = text.lowercased()
        
        // Phrases that indicate hypothetical/conditional language — skip rejection detection
        let conditionalPrefixes = ["if you are ", "if you're ", "in case you ", "should you "]
        
        let statusPatterns: [(ApplicationStatus, [String])] = [
            (.offer, [
                "pleased to offer", "we'd like to offer", "offer letter",
                "we are excited to offer", "extend an offer", "congratulations",
                "welcome to the team"
            ]),
            (.rejected, [
                "unfortunately", "not moving forward", "will not be moving",
                "decided not to", "other candidates",
                "regret to inform", "unable to offer", "wish you the best",
                "after careful consideration"
            ]),
            (.interview, [
                "schedule an interview", "interview invitation", "like to interview",
                "next round", "phone screen", "technical interview",
                "would like to speak", "meet with our team", "interview with"
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
                    // Check if this match is inside a conditional/hypothetical sentence
                    if status == .rejected {
                        let isConditional = conditionalPrefixes.contains { conditional in
                            if let condRange = lowered.range(of: conditional),
                               let phraseRange = lowered.range(of: phrase) {
                                // Check if the conditional appears before the phrase
                                // and they're in the same sentence
                                let sentenceStart = lowered[..<phraseRange.lowerBound]
                                    .lastIndex(of: ".") ?? lowered.startIndex
                                return condRange.lowerBound >= sentenceStart &&
                                       condRange.lowerBound < phraseRange.lowerBound
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
    
    /// Uses Apple's NSDataDetector to find dates in the email.
    /// Falls back to today's date if none found.
    private func extractDate(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        
        let matches = detector?.matches(in: text, options: [], range: range) ?? []
        
        // Return the first reasonable date (not in the distant past or future)
        let now = Date()
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: now)!
        let oneMonthAhead = Calendar.current.date(byAdding: .month, value: 1, to: now)!
        
        for match in matches {
            if let date = match.date,
               date >= sixMonthsAgo && date <= oneMonthAhead {
                return date
            }
        }
        
        return Date() // Fallback to today
    }
    
    // MARK: - Helpers
    
    private func extractCaptureGroup(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
