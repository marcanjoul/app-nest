import SwiftUI
import Testing
@testable import AppNest

@Test("DM Sans loads and its weight axis responds")
func displayFontWeights() throws {
    let regular = try #require(Theme.displayUIFont(size: 17, weight: .regular))
    let bold = try #require(Theme.displayUIFont(size: 17, weight: .bold))
    #expect(regular.fontName.lowercased().contains("dmsans"))
    // Same text, heavier wght → wider strokes → wider line.
    let text = "No applications yet"
    let width = { (f: UIFont) in (text as NSString).size(withAttributes: [.font: f]).width }
    #expect(width(bold) > width(regular))
}
