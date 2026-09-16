import Foundation
import Testing
@testable import AppNest

/// The parser is pure (String in, ParsedResult out) and the only part of the app whose
/// bugs are invisible — a wrong company name looks exactly like a right one. Cases here
/// come from the real-email examples cited in EmailParser's own comments, so a regex
/// tweak that fixes one ATS format and breaks another shows up here instead of in a
/// job entry months later.
private let parser = EmailParser()

// MARK: - Company

@Suite("Company extraction")
struct CompanyTests {

    @Test("pulls the company out of common phrasings", arguments: [
        ("We're excited about you joining BillionToOne and starting soon.", "BillionToOne"),
        ("Thank you for taking the time to submit an application to Snackpass.", "Snackpass"),
        ("We encourage you to learn more about Intuitive and the work we do.", "Intuitive"),
        ("We're glad you want to be a part of Okta's momentum.", "Okta"),
        ("Thank you for your interest in Pindrop and for the time you invested.", "Pindrop"),
        ("Thank you for your interest in a career at Norstella.", "Norstella"),
        ("Helios Medical is committed to building a diverse team.", "Helios Medical"),
        ("We received your application for the role at Datadog.", "Datadog"),
    ])
    func extractsCompany(email: String, expected: String) {
        #expect(parser.parse(email).companyName == expected)
    }

    @Test("a sign-off line names the company when the body doesn't")
    func signOffLine() {
        let email = """
        Thanks for your time today. We'll be in touch with next steps shortly.

        The Waymo Team
        """
        #expect(parser.parse(email).companyName == "Waymo")
    }

    @Test("collective nouns aren't part of the name")
    func stripsCollectiveSuffix() {
        // "the Yara Network" names the company Yara.
        #expect(parser.parse("We received your application for the role at Yara Network.").companyName == "Yara")
        #expect(parser.parse("We received your application for the role at Stripe Talent Community.").companyName == "Stripe")
    }

    @Test("the name stops before a trailing date")
    func doesNotSwallowTrailingDate() {
        // Regression: "applied to X on <date>" captured straight through the date,
        // yielding "Acme on March 3" as the company name.
        #expect(parser.parse("You applied to Acme on March 3.").companyName == "Acme")
        #expect(parser.parse("You applied to Acme on Monday.").companyName == "Acme")
    }

    @Test("requisition IDs are not part of the name")
    func stripsRequisitionID() {
        #expect(parser.parse("You applied to Acme - 30788 last week.").companyName == "Acme")
    }
}

// MARK: - Position

@Suite("Position extraction")
struct PositionTests {

    @Test("reads the title out of the sentence", arguments: [
        ("Thank you for applying for the Software Engineer position.", "Software Engineer"),
        ("We are interviewing you for the Data Analyst role.", "Data Analyst"),
        ("Role: Backend Engineer", "Backend Engineer"),
    ])
    func extractsPosition(email: String, expected: String) {
        #expect(parser.parse(email).position == expected)
    }

    @Test("ATS emails put the title on its own line")
    func titleOnFollowingLine() {
        let email = """
        Thank you for your application for the position listed below.

        Machine Learning Intern - Full-Time - United States - July Start 210774111

        We will review it shortly.
        """
        #expect(parser.parse(email).position == "Machine Learning Intern")
    }

    @Test("a position that resolved to the company name is discarded")
    func discardsPositionEqualToCompany() {
        // "applying to Snackpass" has no title in it — better nil than a wrong title.
        let result = parser.parse("Thank you for applying to Snackpass.")
        #expect(result.companyName == "Snackpass")
        #expect(result.position == nil)
    }
}

// MARK: - Status

@Suite("Status detection")
struct StatusTests {

    @Test("reads the obvious signals", arguments: [
        ("We are pleased to offer you the position.", ApplicationStatus.offer),
        ("Unfortunately, we have decided not to move forward.", .rejected),
        ("We'd like to schedule an interview next week.", .interview),
        ("Thank you for applying. We have received your application.", .applied),
    ])
    func detectsStatus(email: String, expected: ApplicationStatus) {
        #expect(parser.parse(email).status == expected)
    }

    @Test("a hypothetical interview is not an interview")
    func hypotheticalIsNotStatus() {
        // Boilerplate in nearly every acknowledgment email. Reading this as .interview
        // would wrongly advance the application.
        let email = "Thank you for applying. If you are selected for an interview, we will be in touch."
        #expect(parser.parse(email).status == .applied)
    }

    @Test("a conditional governing an earlier clause still leaves a real invitation")
    func commaSeparatesTheConditional() {
        // The comma is what distinguishes this from the case above.
        let email = "If you are available next week, we would like to schedule an interview."
        #expect(parser.parse(email).status == .interview)
    }

    @Test("describing the hiring process is not an interview invitation")
    func processDescriptionIsNotStatus() {
        let email = "Thank you for applying. Our process involves a phone screen followed by an onsite."
        #expect(parser.parse(email).status == .applied)
    }

    @Test("defaults to applied when nothing matches")
    func defaultsToApplied() {
        #expect(parser.parse("Here is some unrelated text.").status == .applied)
    }
}

// MARK: - Job type and season

@Suite("Job type and season")
struct TypeSeasonTests {

    @Test("detects job type", arguments: [
        ("Applying for our Summer 2026 internship programme.", ApplicationType.internship),
        ("This is a co-op position starting in May.", .Co_op),
        ("We are hiring new grad engineers.", .fullTime),
        ("This is a part-time role.", .partTime),
    ])
    func detectsType(email: String, expected: ApplicationType) {
        #expect(parser.parse(email).jobType == expected)
    }

    @Test("detects season next to a year or a programme noun", arguments: [
        ("Our Summer 2026 internship cohort starts in June.", ApplicationSeason.summer),
        ("Applications for Fall 2026 are open.", .fall),
    ])
    func detectsSeason(email: String, expected: ApplicationSeason) {
        #expect(parser.parse(email).season == expected)
    }

    @Test("\"fall\" as a verb is not a season")
    func fallVerbIsNotASeason() {
        // "fall" is a common English verb, which is why the bare word never matches.
        let email = "If your skills fall short of the requirements, we encourage you to reapply."
        #expect(parser.parse(email).season == nil)
    }
}

// MARK: - Date

@Suite("Date extraction")
struct DateTests {

    @Test("an application date is never in the future")
    func rollsFutureDatesBack() {
        // NSDataDetector resolves a bare month+day to its *next* occurrence, which for an
        // application date is always wrong.
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        let email = "You applied on \(formatter.string(from: nextMonth))."

        let parsed = try! #require(parser.parse(email).dateApplied)
        #expect(parsed <= Date())
    }

    @Test("falls back to now when the email carries no date")
    func defaultsToNow() {
        let parsed = try! #require(parser.parse("Thank you for applying.").dateApplied)
        #expect(abs(parsed.timeIntervalSinceNow) < 5)
    }
}
