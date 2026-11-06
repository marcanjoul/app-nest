import Foundation
import Testing
@testable import AppNest

/// The Share extension packs the shared text into appnest://share?text=… the same way as `url(for:)`.
@Suite("Share URL")
struct ShareURLTests {
    private func url(for text: String) -> URL {
        var c = URLComponents()
        c.scheme = "appnest"
        c.host = "share"
        c.queryItems = [URLQueryItem(name: "text", value: text)]
        return c.url!
    }

    @Test("emails and links survive the trip intact", arguments: [
        "Hi Mark,\n\nThanks for applying to the Product Design Intern role! & more = 100% \"quotes\" + emoji 🎉\n\nStripe",
        "https://jobs.lever.co/acme/123?utm_source=x&ref=y#apply",
    ])
    func roundTrip(text: String) {
        #expect(AppState.sharedText(from: url(for: text)) == text)
    }

    @Test("other URLs are ignored")
    func ignoresOthers() {
        #expect(AppState.sharedText(from: URL(string: "appnest://share")!) == nil)
        #expect(AppState.sharedText(from: URL(string: "appnest://other?text=hi")!) == nil)
    }
}
