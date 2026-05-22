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
    var isPresentingSheet = false

    /// Main navigation path for the Applications tab.
    var navigationPath = NavigationPath()

    /// Job tapped from the list — presented as a fullScreenCover sliding up from bottom.
    var selectedJob: JobApplication?
    
    /// Triggered when the user taps the 'Add' tab while already on it, or when switching away.
    var shouldResetAddMenu = false
    
    /// Tracks if the main application list entrance animation has already played.
    var dashboardHasAppeared = false
    /// Tracks if the cycle list entrance animation has already played.
    var cycleListHasAppeared = false

    /// Incrementing this scrolls ApplicationView back to the top.
    var scrollToTopTrigger: Int = 0

    // MARK: - Share Extension Import
    var pendingJobImport: PendingJobImport?

    init() {
        selectedCycleID = UserDefaults.standard.string(forKey: "appnest.selectedCycleID")
            .flatMap(UUID.init(uuidString:))
    }
}

