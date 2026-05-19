import SwiftUI
import SwiftData
import PhotosUI

@Observable
final class EmailParseViewModel {

    // MARK: - Input state

    var emailText = ""
    var isParsing = false
    var isEmailExpanded = true
    var isButtonPressed = false

    // MARK: - Result state

    var hasResult = false
    var editCompany = ""
    var editPosition = ""
    var editJobType: ApplicationType? = nil
    var editStatus: ApplicationStatus = .applied
    var editSeason: ApplicationSeason? = nil
    var editDate: Date = Date()
    var editCompensationKind: CompensationKind? = nil
    var editCompensationAmount: Double? = nil
    var editCompensationCurrency: Currency? = .usd
    var editSalaryPeriod: SalaryPeriod? = .yearly
    var editNotes = ""
    var editAttachedResume: ResumeDocument? = nil

    // MARK: - UI state

    var parseCount = 0
    var saveSuccess = false
    var fetchedLogoData: Data? = nil
    var isFetchingLogo = false
    var highlights: [HighlightSpan] = []
    var isHighlightExpanded = false
    var pickerItem: PhotosPickerItem? = nil

    private let emailParser = EmailParser()

    // MARK: - Computed

    var isParseDisabled: Bool {
        emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing
    }

    var isSaveDisabled: Bool {
        editCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    /// Resets all state with haptic. Call for user-initiated cancel/collapse.
    func reset() {
        AppHaptics.shared.light()
        withAnimation(.appSmooth) { resetState() }
    }

    /// Resets all state without haptic or animation. Call from within an existing animation block.
    func resetState() {
        emailText = ""
        hasResult = false
        editCompany = ""
        editPosition = ""
        editJobType = nil
        editStatus = .applied
        editSeason = nil
        editDate = Date()
        editCompensationKind = nil
        editCompensationAmount = nil
        editNotes = ""
        editAttachedResume = nil
        isEmailExpanded = true
        fetchedLogoData = nil
        isFetchingLogo = false
        highlights = []
        isHighlightExpanded = false
        saveSuccess = false
    }

    func parseEmail(defaultResume: ResumeDocument?, onParsed: (() -> Void)? = nil) {
        guard !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        #if canImport(UIKit)
        UIApplication.shared.dismissKeyboard()
        #endif
        AppHaptics.shared.medium()
        withAnimation(.appSmooth) { isParsing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            let result = self.emailParser.parse(self.emailText)
            withAnimation(.appSmooth) {
                self.editCompany = result.companyName ?? ""
                self.editPosition = result.position ?? ""
                self.editJobType = result.jobType
                self.editStatus = result.status ?? .applied
                self.editSeason = nil
                self.editDate = result.dateApplied ?? Date()
                self.editCompensationKind = nil
                self.editCompensationAmount = nil
                self.editNotes = ""
                self.editAttachedResume = defaultResume
                self.isParsing = false
                self.hasResult = true
                self.isEmailExpanded = false
                self.parseCount += 1
                self.highlights = result.highlights
                self.isHighlightExpanded = false
            }
            onParsed?()
        }
    }

    func saveApplication(
        modelContext: ModelContext,
        cycles: [JobCycle],
        selectedCycleID: UUID?,
        onSaved: @escaping () -> Void
    ) {
        let attached = editAttachedResume
        let selectedCycle = selectedCycleID.flatMap { id in cycles.first { $0.id == id } }
        modelContext.insert(JobApplication(
            companyName: editCompany.isEmpty ? "Unknown Company" : editCompany,
            companyLogoImageData: fetchedLogoData,
            position: editPosition.isEmpty ? "Unknown Position" : editPosition,
            jobType: editJobType,
            status: editStatus,
            season: editSeason,
            cycle: selectedCycle,
            dateApplied: editDate,
            jobNotes: editNotes,
            resumeFileName: attached?.fileName,
            resumeBookmark: attached?.bookmark,
            resumeID: attached?.id,
            compensationKind: editCompensationKind,
            compensationAmount: editCompensationAmount,
            compensationCurrency: editCompensationCurrency,
            salaryPeriod: editSalaryPeriod
        ))
        AppHaptics.shared.success()
        withAnimation(.appSmooth) { saveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            withAnimation(.appSmooth) {
                self.resetState()
                onSaved()
            }
        }
    }

    // MARK: - Highlight helpers

    func highlightColor(for field: HighlightField) -> Color {
        switch field {
        case .company:  return Color.accentColor
        case .position: return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .status:   return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .date:     return Color(red: 0.62, green: 0.52, blue: 0.96)
        }
    }

    func buildHighlightedString(_ raw: String, spans: [HighlightSpan]) -> AttributedString {
        var result = AttributedString(raw)
        let nsRaw = raw as NSString
        for span in spans {
            let color = highlightColor(for: span.field)
            var searchStart = 0
            while searchStart < nsRaw.length {
                let searchRange = NSRange(location: searchStart, length: nsRaw.length - searchStart)
                let found = nsRaw.range(of: span.text, options: .caseInsensitive, range: searchRange)
                guard found.location != NSNotFound else { break }
                if let swiftRange = Range(found, in: raw) {
                    let lo = result.index(result.startIndex, offsetByCharacters: raw.distance(from: raw.startIndex, to: swiftRange.lowerBound))
                    let hi = result.index(result.startIndex, offsetByCharacters: raw.distance(from: raw.startIndex, to: swiftRange.upperBound))
                    result[lo..<hi].foregroundColor = color
                    result[lo..<hi].font = Font.system(size: 14, weight: .bold)
                }
                searchStart = found.location + found.length
            }
        }
        return result
    }
}
