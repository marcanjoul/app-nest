import Foundation
import Observation

@Observable
class AppState {
    var selectedCycleID: UUID?

    // MARK: - CSV Import
    var isImportingCSV = false
    var csvImportPreview: [CSVImportRow]?
    var isShowingImportPreview = false
    var csvImportSkippedCount: Int = 0
}
