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

// MARK: - Full emails

@Suite("Full email parsing")
struct FullEmailTests {

    @Test("ATS confirmation with a long title that carries a location")
    func amexConfirmation() {
        let email = """
        Hello Mark,

        Thank you for exploring new career opportunities with American Express! Your application for the position of Campus Undergraduate Full-Time Engineer - 2027 AI Engineer I, Enterprise Technology Services- Phoenix, AZ has been received.
        """
        let result = parser.parse(email)
        #expect(result.companyName == "American Express")
        #expect(result.position == "Campus Undergraduate Full-Time Engineer - 2027 AI Engineer I, Enterprise Technology Services")
        #expect(result.jobType == .fullTime)
        #expect(result.status == .applied)
        #expect(result.location == "Phoenix, AZ")
        #expect(result.highlights.contains { $0.field == .status })
    }

    @Test("Ashby template: title with commas, company with a domain suffix")
    func ashbyConfirmation() {
        let email = """
        Dear Mark,

        Thank you for taking the time to submit your application for Software Engineer, Front-End (New Grad) and considering Otter.ai for your next role! We understand the time and thought that goes into applying for positions and we will review your application with our hiring team promptly.
        """
        let result = parser.parse(email)
        #expect(result.companyName == "Otter.ai")
        #expect(result.position == "Software Engineer, Front-End (New Grad)")
        #expect(result.jobType == .fullTime)
    }

    @Test("Disney: title prefixed by a division name and suffixed by a season")
    func disneyConfirmation() {
        let email = "Thank you for sharing your story with us! We are delighted by the interest you've shown in The Walt Disney Company and the Walt Disney Animation Studios Product Design Intern, Summer 2027 position."
        let result = parser.parse(email)
        #expect(result.companyName == "Walt Disney Company")
        #expect(result.position == "Product Design Intern")
        #expect(result.jobType == .internship)
        #expect(result.season == .summer)
    }

    @Test("Amazon: title after \"interest in\", with an en-dash season and an ID tag")
    func amazonConfirmation() {
        let email = """
        Hi Mark,

        Thank you for your interest in UX Designer Intern – Summer 2027 (ID: 10592766).

        If you have completed the application:
        Great! You can now check the application status here.

        Best regards,
        Amazon Recruiting Team
        """
        let result = parser.parse(email)
        #expect(result.companyName == "Amazon")
        #expect(result.position == "UX Designer Intern")
        #expect(result.jobType == .internship)
        #expect(result.season == .summer)
        #expect(result.status == .applied)
    }

    @Test("KAYAK: \"Apply for\" posting title, venue before the company")
    func kayakConfirmation() {
        let email = """
        Hi Mark,

        Thank you for taking the time to apply for the Apply for KAYAK Product, Design & Tech Opportunities at the SWE Conference at KAYAK. We appreciate your interest in joining our team and the effort you put into your application.
        """
        let result = parser.parse(email)
        #expect(result.companyName == "KAYAK")
        #expect(result.position == "Product, Design & Tech Opportunities")
        #expect(result.status == .applied)
    }

    @Test("Databricks: bare year in parentheses isn't part of the title")
    func databricksConfirmation() {
        let email = """
        Hi Mark,

        Thanks for applying to Databricks! Your application for the Software Engineering Intern (2027) role has been received. We will review it shortly and reach out if there is a fit.

        Regards,
        Databricks
        """
        let result = parser.parse(email)
        #expect(result.companyName == "Databricks")
        #expect(result.position == "Software Engineering Intern")
        #expect(result.jobType == .internship)
        #expect(result.season == nil)
        #expect(result.status == .applied)
    }

    @Test("work mode from phrasing; remote drops the city")
    func workModeFromPhrasing() {
        #expect(parser.parse("Thanks for applying to this fully remote role at Acme.").workMode == .remote)
        #expect(parser.parse("This hybrid position is based in Austin, TX.").workMode == .hybrid)
        #expect(parser.parse("This hybrid position is based in Austin, TX.").location == "Austin, TX")
        #expect(parser.parse("Thanks for applying to Acme. We'll be in touch.").location == nil)
    }

    @Test("Pfizer: company named only by its program, title led by season and year")
    func pfizerConfirmation() {
        let email = """
        Dear Mark,

        Thank you for your application to the Summer 2027 Digital & Technology Internship.This email confirms that we have successfully received your application.

        If you are invited to complete the assessment, please be advised that you are only required to complete it once, regardless of the number of positions you have applied to within the Pfizer Futures Program.

        Kind regards,

        Atrium Works
        Pfizer Futures Program Team
        """
        let result = parser.parse(email)
        #expect(result.companyName == "Pfizer")
        #expect(result.position == "Digital & Technology Internship")
        #expect(result.jobType == .internship)
        #expect(result.season == .summer)
        #expect(result.status == .applied)
    }

    @Test("a generic program name isn't a company")
    func genericProgramIsNotCompany() {
        #expect(parser.parse("Thanks for applying to the Summer Internship Program.").companyName != "Summer")
    }

    @Test("RTX: title in brackets with a req number, company only in the sign-off")
    func rtxConfirmation() {
        let email = """
        Hi Mark Anjoul ,

        Thank you for your interest in our open position ( 01884409 Systems Engineer Intern ). We look forward to reviewing your skills, qualifications and experience. If your profile meets the requirements of our open position, a member of our recruiting team will be in contact with you soon.

        Regards,

        RTX Global Talent Acquisition
        """
        let result = parser.parse(email)
        #expect(result.companyName == "RTX")
        #expect(result.position == "Systems Engineer Intern")
        #expect(result.jobType == .internship)
        #expect(result.status == .applied)
    }
}

@Suite("Stripe acknowledgment")
struct StripeAckTests {
    @Test("names the company from 'at Stripe' / sign-off")
    func stripe() {
        let email = """
        Hi Mark,

        Thanks so much for submitting your application for the Product Design Intern role! As a reminder, we have recorded your location preferences based on your application responses so only one application is required.

        With the high volume of applications, our University Recruiting team will review applications on a rolling basis which may cause a delay in our response times. We appreciate your understanding and, in the meantime, encourage you to check out our quick guide to Stripe culture [0], our blog [1], and our LinkedIn page [2] to get a feel for what we're up to at Stripe.

        We hope to connect soon!

        Stripe
        """
        let r = parser.parse(email)
        #expect(r.companyName == "Stripe")
        #expect(r.position == "Product Design Intern")
    }
}
