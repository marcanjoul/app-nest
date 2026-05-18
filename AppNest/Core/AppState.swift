import Foundation
import Observation

@Observable
class AppState {
    var selectedCycleID: UUID?

    // MARK: - Navigation & Interaction
    var isPresentingSheet = false

    // MARK: - Share Extension Import
    var pendingJobImport: PendingJobImport?
}
