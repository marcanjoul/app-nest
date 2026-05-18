import Foundation
import Observation

@Observable
class AppState {
    var selectedCycleID: UUID?
}
