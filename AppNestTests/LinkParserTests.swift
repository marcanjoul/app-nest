import Foundation
import Testing
@testable import AppNest

/// Offline cases only — the Greenhouse lookup needs the network.
@Suite("Link parsing")
struct LinkParserTests {

    @Test("text that isn't a web address is rejected before parsing", arguments: [
        "hello world", "notaurl", "ftp://example.com/jobs", "Thank you for applying!",
    ])
    func rejectsNonURLs(text: String) {
        #expect(LinkParser.webURL(from: text) == nil)
    }

    @Test("bare domains are accepted")
    func acceptsBareDomain() {
        #expect(LinkParser.webURL(from: "stripe.com/jobs/123")?.absoluteString == "https://stripe.com/jobs/123")
    }

    @Test("a real link that isn't a job posting is flagged", arguments: [
        "google.com", "https://www.google.com/search?q=jobs+near+me", "https://twitter.com/acme",
    ])
    func flagsNonJobLinks(url: String) async {
        #expect(await LinkParser().parse(url).isNotJobLink)
    }

    @Test("careers domains name the company, not the careers site")
    func stripsCareersAffix() {
        #expect(LinkParser.stripCareersAffix("pinterestcareers") == "pinterest")
        #expect(LinkParser.stripCareersAffix("careers") == "careers")
    }
}

/// Hits Ashby's public job-board API — needs the network, and the posting may eventually close.
@Test("Ashby links pull the job title from the board API")
func parsesAshbyTitle() async {
    let r = await LinkParser().parse("https://jobs.ashbyhq.com/aurora-operations-inc/475a24d7-a058-4f86-be8f-fd6be679af9c/application?jr_id=6adfd6ee065c4e77efafc1ef")
    #expect(r.companyName == "Aurora Operations")
    #expect(r.position == "AI Engineer Intern")
    #expect(r.jobType == .internship)
}

/// Hits Lever's public postings API — needs the network, and the posting may eventually close.
@Test("Lever links pull the job title and commitment from the postings API")
func parsesLeverTitle() async {
    let r = await LinkParser().parse("https://jobs.lever.co/palantir/6ed76ce8-4156-4b60-b120-403538bd66cd")
    #expect(r.companyName == "Palantir")
    #expect(r.position == "Administrative Business Partner")
    #expect(r.jobType == .fullTime)
}

@Test("legal suffixes are dropped from company names", arguments: [
    ("Aurora Operations Inc", "Aurora Operations"), ("Acme, LLC", "Acme"), ("Foo Ltd.", "Foo"),
    ("Big Corp", "Big"), ("Corp", "Corp"), ("Incubator", "Incubator"),
])
func stripsLegalSuffix(input: String, expected: String) {
    #expect(LinkParser.stripLegalSuffix(input) == expected)
}

@Test("ATS locations split into a place and a work mode", arguments: [
    ("Remote - US", nil as String?, nil as String?, WorkMode.remote as WorkMode?),
    ("New York, NY (Hybrid)", nil, "New York, NY", .hybrid),
    ("Pittsburgh, PA", "OnSite", "Pittsburgh, PA", .onSite),
    ("Singapore, Singapore", "hybrid", "Singapore, Singapore", .hybrid),
    ("Tokyo, Japan", nil, "Tokyo, Japan", nil),
    ("Austin, TX", "unspecified", "Austin, TX", nil),
])
func splitsLocation(raw: String, workplaceType: String?, place: String?, mode: WorkMode?) {
    let (location, workMode) = LinkParser.splitLocation(raw, workplaceType: workplaceType)
    #expect(location == place)
    #expect(workMode == mode)
}

@Test("Workday location segments: City-ST only")
func readsWorkdayLocation() {
    #expect(LinkParser.workdayLocation("San-Francisco-CA") == "San Francisco, CA")
    #expect(LinkParser.workdayLocation("Remote-USA") == "Remote")
    #expect(LinkParser.workdayLocation("US-CA-San-Francisco") == nil)
}
