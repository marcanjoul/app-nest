import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct JobDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]

    var job: JobApplication?

    // MARK: - State

    @State private var companyName:       String
    @State private var companyLogoName:   String
    @State private var companyLogoImageData: Data?
    @State private var position:          String
    @State private var type:              ApplicationType?
    @State private var status:            ApplicationStatus?
    @State private var season:            ApplicationSeason?
    @State private var dateApplied:       Date
    @State private var jobNotes:          String
    @State private var resumeFileName:    String?
    @State private var resumeID:          UUID?
    @State private var _pendingResumeBookmark: Data?
    @State private var compensationKind:     CompensationKind?
    @State private var compensationAmount:   String
    @State private var compensationCurrency: Currency
    @State private var salaryPeriod:         SalaryPeriod
    @State private var isShowingDocumentPicker = false
    @State private var isShowingResumeLibrary = false
    @State private var pickerItem: PhotosPickerItem? = nil

    private var isNewApplication: Bool { job == nil }

    private var isSaveDisabled: Bool {
        !missingFields.isEmpty
    }

    private var missingFields: [String] {
        var fields: [String] = []
        if companyName.trimmingCharacters(in: .whitespaces).isEmpty { fields.append("Company") }
        if position.trimmingCharacters(in: .whitespaces).isEmpty   { fields.append("Position") }
        if type == nil                                              { fields.append("Type") }
        if status == nil                                            { fields.append("Status") }
        return fields
    }

    private var isSeasonAllowed: Bool {
        let allowed: [ApplicationType] = [.partTime, .internship, .temporary, .Co_op]
        return type.map { allowed.contains($0) } ?? false
    }

    init(job: JobApplication?) {
        self.job = job
        _companyName            = State(initialValue: job?.companyName ?? "")
        _companyLogoName        = State(initialValue: job?.companyLogoName ?? "")
        _companyLogoImageData   = State(initialValue: job?.companyLogoImageData)
        _position               = State(initialValue: job?.position ?? "")
        _type                   = State(initialValue: job?.jobType)
        _status                 = State(initialValue: job?.status ?? .applied)
        _season                 = State(initialValue: job?.season)
        _dateApplied            = State(initialValue: job?.dateApplied ?? Date())
        _jobNotes               = State(initialValue: job?.jobNotes ?? "")
        _resumeFileName         = State(initialValue: job?.resumeFileName)
        _resumeID               = State(initialValue: job?.resumeID)
        __pendingResumeBookmark = State(initialValue: nil)
        _compensationKind       = State(initialValue: job?.compensationKind)
        _compensationAmount     = State(initialValue: job?.compensationAmount.map { Self.formatAmount($0) } ?? "")
        _compensationCurrency   = State(initialValue: job?.compensationCurrency ?? .usd)
        _salaryPeriod           = State(initialValue: job?.salaryPeriod ?? .yearly)
    }

    private static func formatAmount(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%g", value)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 16) {
                    JobInfoSection(
                        companyName: $companyName,
                        companyLogoName: $companyLogoName,
                        companyLogoImageData: $companyLogoImageData,
                        position: $position,
                        pickerItem: $pickerItem
                    )

                    TypePickerSection(type: $type)
                    StatusPickerSection(status: $status)
                    if isSeasonAllowed {
                        SeasonPickerSection(season: $season)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                    }
                    DateAppliedSection(dateApplied: $dateApplied)
                    CompensationSection(
                        kind: $compensationKind,
                        amount: $compensationAmount,
                        currency: $compensationCurrency,
                        salaryPeriod: $salaryPeriod
                    )
                    ResumeSection(
                        resumes: orderedResumes,
                        attachedResume: attachedResume,
                        legacyResumeFileName: resumeID == nil ? resumeFileName : nil,
                        attachedResumeWasDeleted: attachedResumeWasDeleted,
                        onSelectResume: attachResume,
                        onViewAll: { isShowingResumeLibrary = true },
                        onPick: { isShowingDocumentPicker = true },
                        onClear: {
                            if let attached = attachedResume {
                                modelContext.delete(attached)
                            }
                            resumeID = nil
                            resumeFileName = nil
                            _pendingResumeBookmark = nil
                        }
                    )
                    JobNotesSection(jobNotes: $jobNotes)
                }
                .onChange(of: type) { _, _ in
                    if !isSeasonAllowed { season = nil }
                }
                .animation(.easeInOut(duration: 0.22), value: isSeasonAllowed)
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPicker { result in
                if case .success(let picked) = result {
                    attachPickedResume(fileName: picked.fileName, bookmark: picked.bookmark)
                }
            }
        }
        .sheet(isPresented: $isShowingResumeLibrary) {
            ResumeLibrarySheet(
                resumes: orderedResumes,
                attachedResumeID: resumeID,
                onSelectResume: { resume in
                    attachResume(resume)
                    isShowingResumeLibrary = false
                }
            )
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                HStack {
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        save()
                        dismiss()
                    } label: {
                        Text(isNewApplication ? "Add Application" : "Save Changes")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background {
                                Capsule()
                                    .fill(isSaveDisabled ? Color.secondary.opacity(0.3) : Color.accentColor)
                                    .overlay {
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.20), Color.clear],
                                            startPoint: .top, endPoint: .center
                                        )
                                        .clipShape(Capsule())
                                    }
                                    .shadow(color: isSaveDisabled ? .clear : Color.accentColor.opacity(0.45), radius: 10, y: 3)
                            }
                    }
                    .disabled(isSaveDisabled)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .animation(.easeInOut(duration: 0.2), value: isSaveDisabled)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
            }
            if isNewApplication {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .navigationTitle(isNewApplication ? "New Application" : "Job Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Save

    private func save() {
        let parsedAmount = parsedCompensationAmount
        let resolvedSalaryPeriod: SalaryPeriod? = compensationKind == .salary ? salaryPeriod : nil

        if let job {
            job.companyName         = companyName
            job.companyLogoName     = companyLogoName
            job.companyLogoImageData = companyLogoImageData
            job.position            = position
            job.jobType             = type
            job.status              = status
            job.season              = season
            job.dateApplied         = dateApplied
            job.jobNotes            = jobNotes
            job.resumeFileName      = resumeFileName
            job.resumeBookmark      = _pendingResumeBookmark ?? job.resumeBookmark
            job.resumeID            = resumeID
            job.compensationKind    = compensationKind
            job.compensationAmount  = parsedAmount
            job.compensationCurrency = compensationCurrency
            job.salaryPeriod        = resolvedSalaryPeriod
        } else {
            modelContext.insert(JobApplication(
                companyName: companyName,
                companyLogoName: companyLogoName,
                companyLogoImageData: companyLogoImageData,
                position: position,
                jobType: type,
                status: status,
                season: season,
                dateApplied: dateApplied,
                jobNotes: jobNotes,
                resumeFileName: resumeFileName,
                resumeBookmark: _pendingResumeBookmark,
                resumeID: resumeID,
                compensationKind: compensationKind,
                compensationAmount: parsedAmount,
                compensationCurrency: compensationCurrency,
                salaryPeriod: resolvedSalaryPeriod
            ))
        }
    }

    private var parsedCompensationAmount: Double? {
        let cleaned = compensationAmount
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    private var defaultResume: ResumeDocument? {
        resumes.first(where: \.isDefault)
    }

    private var orderedResumes: [ResumeDocument] {
        guard let defaultResume else { return resumes }
        return [defaultResume] + resumes.filter { $0.id != defaultResume.id }
    }

    private var attachedResume: ResumeDocument? {
        guard let resumeID else { return nil }
        return resumes.first { $0.id == resumeID }
    }

    private var attachedResumeWasDeleted: Bool {
        resumeID != nil && attachedResume == nil
    }

    private func attachPickedResume(fileName: String, bookmark: Data) {
        let resume = existingResume(fileName: fileName) ?? createResume(fileName: fileName, bookmark: bookmark)
        resume.bookmark = bookmark
        resumeID = resume.id
        resumeFileName = resume.fileName
        _pendingResumeBookmark = bookmark
    }

    private func attachResume(_ resume: ResumeDocument) {
        resumeID = resume.id
        resumeFileName = resume.fileName
        _pendingResumeBookmark = resume.bookmark
    }

    private func existingResume(fileName: String) -> ResumeDocument? {
        resumes.first { $0.fileName == fileName }
    }

    private func createResume(fileName: String, bookmark: Data) -> ResumeDocument {
        let resume = ResumeDocument(
            fileName: fileName,
            bookmark: bookmark,
            isDefault: resumes.isEmpty || !resumes.contains(where: \.isDefault)
        )
        modelContext.insert(resume)
        return resume
    }
}

// MARK: - Type Picker

private struct TypePickerSection: View {
    @Binding var type: ApplicationType?

    private var orderedOptions: [ApplicationType] {
        if let selected = type {
            return [selected] + ApplicationType.allCases.filter { $0 != selected }
        }
        return ApplicationType.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "list.bullet", title: "Job Type", isRequired: true)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(orderedOptions, id: \.self) { option in
                            SelectablePill(
                                option: option,
                                isSelected: option == type,
                                color: option.color,
                                icon: option.iconName,
                                onTap: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                                        type = (type == option ? nil : option)
                                    }
                                }
                            )
                            .id(option)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .onChange(of: type) { _, _ in
                    if let first = orderedOptions.first {
                        withAnimation(.smooth) { proxy.scrollTo(first, anchor: .leading) }
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Status Picker

private struct StatusPickerSection: View {
    @Binding var status: ApplicationStatus?

    private var orderedOptions: [ApplicationStatus] {
        if let selected = status {
            return [selected] + ApplicationStatus.allCases.filter { $0 != selected }
        }
        return ApplicationStatus.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "rectangle.and.hand.point.up.left.fill", title: "Status", isRequired: true)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(orderedOptions, id: \.self) { option in
                            SelectablePill(
                                option: option,
                                isSelected: option == status,
                                color: option.color,
                                icon: option.iconName,
                                onTap: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                                        status = (status == option ? nil : option)
                                    }
                                }
                            )
                            .id(option)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .onChange(of: status) { _, _ in
                    if let first = orderedOptions.first {
                        withAnimation(.easeOut) { proxy.scrollTo(first, anchor: .leading) }
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Season Picker

private struct SeasonPickerSection: View {
    @Binding var season: ApplicationSeason?

    private var orderedOptions: [ApplicationSeason] {
        if let selected = season {
            return [selected] + ApplicationSeason.allCases.filter { $0 != selected }
        }
        return ApplicationSeason.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "sun.snow.fill", title: "Season")

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(orderedOptions, id: \.self) { option in
                            SelectablePill(
                                option: option,
                                isSelected: option == season,
                                color: option.color,
                                icon: option.iconName,
                                onTap: {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                                        season = (season == option ? nil : option)
                                    }
                                }
                            )
                            .id(option)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .onChange(of: season) { _, _ in
                    if let first = orderedOptions.first {
                        withAnimation(.easeOut) { proxy.scrollTo(first, anchor: .leading) }
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Date Section

private struct DateAppliedSection: View {
    @Binding var dateApplied: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(icon: "calendar", title: "Date Applied")

            HStack {
                Spacer()
                DatePicker(
                    "",
                    selection: $dateApplied,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .controlSize(.large)
                Spacer()
            }
            .padding(.vertical, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Notes Section

private struct JobNotesSection: View {
    @Binding var jobNotes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "square.and.pencil", title: "Notes")

            ZStack(alignment: .topLeading) {
                if jobNotes.isEmpty {
                    Text("Add notes about this job…")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                }
                TextEditor(text: $jobNotes)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 130)
                    .font(.subheadline)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        JobDetailView(job: JobApplication(
            companyName: "Meta",
            companyLogoName: "meta",
            position: "Software Engineering Intern – 2026",
            dateApplied: Date()
        ))
    }
    .modelContainer(for: [JobApplication.self, ResumeDocument.self], inMemory: true)
}
