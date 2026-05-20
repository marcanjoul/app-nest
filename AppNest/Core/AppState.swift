import Foundation
import Observation

@Observable
class AppState {
    var selectedCycleID: UUID? {
        didSet { UserDefaults.standard.set(selectedCycleID?.uuidString, forKey: "appnest.selectedCycleID") }
    }
    var selectedTab: Int = 0

    // MARK: - Navigation & Interaction
    var isPresentingSheet = false

    // MARK: - Share Extension Import
    var pendingJobImport: PendingJobImport?

    init() {
        selectedCycleID = UserDefaults.standard.string(forKey: "appnest.selectedCycleID")
            .flatMap(UUID.init(uuidString:))
    }
}
