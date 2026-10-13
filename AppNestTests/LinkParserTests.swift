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
