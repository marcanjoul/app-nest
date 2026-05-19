import Foundation
import Observation

@Observable
class AppState {
    var selectedCycleID: UUID?
    var selectedTab: Int = 0

    // MARK: - Navigation & Interaction
    var isPresentingSheet = false

    // MARK: - Share Extension Import
    var pendingJobImport: PendingJobImport?
}
