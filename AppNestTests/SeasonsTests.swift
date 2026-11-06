import Testing
@testable import AppNest

/// `seasons` is stored as a joined string beside the legacy `season` column; these pin the
/// two staying in sync so old stores, CSV export and filters keep working.
@Suite("Multiple seasons")
struct SeasonsTests {

    @Test("a job saved before multi-season reads its single season")
    func legacyFallback() {
        let job = JobApplication(companyName: "Acme", position: "Intern", season: .summer)
        #expect(job.seasons == [.summer])
    }

    @Test("setting seasons orders them by calendar and keeps `season` as the first")
    func setterSyncsLegacyColumn() {
        let job = JobApplication(companyName: "Acme", position: "Co-op")
        job.seasons = [.fall, .summer]
        #expect(job.seasons == [.summer, .fall])
        #expect(job.season == .summer)
    }

    @Test("clearing seasons clears the legacy column too")
    func clearing() {
        let job = JobApplication(companyName: "Acme", position: "Co-op", season: .winter)
        job.seasons = []
        #expect(job.seasons.isEmpty)
        #expect(job.season == nil)
    }
}

@Suite("CSV seasons")
struct CSVSeasonsTests {
    @Test("an exported 'Summer / Fall' cell imports as both seasons")
    func multiSeasonRoundTrip() {
        let csv = "Company,Position,Season\nStripe,Design Intern,Summer / Fall\n"
        #expect(CSVImporter.parse(csv).first?.seasons == [.summer, .fall])
    }

    @Test("autumn reads as fall; unknown text is no season")
    func aliases() {
        #expect(CSVImporter.matchSeasons("Autumn 2026") == [.fall])
        #expect(CSVImporter.matchSeasons("TBD").isEmpty)
    }
}
