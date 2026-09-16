import Foundation
import SwiftUI
import Observation

typealias NavigationPath = SwiftUI.NavigationPath

@Observable
class AppState {
    var selectedCycleID: UUID? {
        didSet { UserDefaults.standard.set(selectedCycleID?.uuidString, forKey: "appnest.selectedCycleID") }
    }
    var selectedTab: Int = 0

    // MARK: - Navigation & Interaction
    
    /// Global trigger for the full-screen offer celebration.
    var showOfferCelebration = false

    /// Main navigation path for the Applications tab.
    var navigationPath = NavigationPath()

    /// Job tapped from the list — presented as a fullScreenCover sliding up from bottom.
    var selectedJob: JobApplication?
    
    /// Tracks if the cycle list entrance animation has already played.
    var cycleListHasAppeared = false


    init() {
        selectedCycleID = UserDefaults.standard.string(forKey: "appnest.selectedCycleID")
            .flatMap(UUID.init(uuidString:))
    }
}
