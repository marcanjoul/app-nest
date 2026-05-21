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
    @Environment(AppState.self)  private var appState
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    var job: JobApplication?

    // MARK: - State

    @State private var companyName:       String
    @State private var companyLogoImageData: Data?
    @State private var position:          String
    @State private var type:              ApplicationType?
    @State private var status:            ApplicationStatus?
    @State private var season:            ApplicationSeason?
    @State private var dateApplied:       Date
    @State private var jobURL:            String
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
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var companyResearch:   String
    @State private var interviewNotes:    String
    @State private var isShowingDeleteConfirmation = false
    @State private var isConfirmingResumeClear = false
    @State private var isShowingLogoAttribution = false
    @State private var shakeMissingFields = false
    @State private var scrollTargetSection: FormSection?
    @State private var contentAppeared = false

    private enum FormSection: Hashable {
        case info, type, status
    }

    private var isNewApplication: Bool { job == nil }

    private var hasChanges: Bool {
        guard let job else { return true }
        let wantsReminder = status == .toApply && reminderEnabled
        let originalWantsReminder = job.reminderEnabled
        let reminderTimeChanged: Bool = {
            guard wantsReminder && originalWantsReminder else { return wantsReminder != originalWantsReminder }
            let cal = Calendar.current
            let orig = cal.dateComponents([.hour, .minute], from: job.reminderTime ?? Self.defaultReminderTime)
            let cur  = cal.dateComponents([.hour, .minute], from: reminderTime)
            return orig.hour != cur.hour || orig.minute != cur.minute
        }()
        return companyName          != job.companyName
            || companyLogoImageData != job.companyLogoImageData
            || position             != job.position
            || type                 != job.jobType
            || status               != job.status
            || season               != job.season
            || dateApplied          != job.dateApplied
            || jobURL.trimmingCharacters(in: .whitespaces) != (job.jobURL ?? "")
            || jobNotes             != (job.jobNotes ?? "")
            || resumeID             != job.resumeID
            || compensationKind     != job.compensationKind
            || parsedCompensationAmount != job.compensationAmount
            || compensationCurrency != (job.compensationCurrency ?? .usd)
            || salaryPeriod         != (job.salaryPeriod ?? .yearly)
            || reminderTimeChanged
            || companyResearch      != (job.companyResearch ?? "")
            || interviewNotes       != (job.interviewNotes ?? "")
    }

    private var isSaveDisabled: Bool {
        !missingFields.isEmpty || (!isNewApplication && !hasChanges)
    }

    private var saveButtonLabel: String {
        if isNewApplication { return "Add Application" }
        if !missingFields.isEmpty { return "Save Changes" }
        return hasChanges ? "Save Changes" : "No Changes"
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

    private var isInterviewStage: Bool {
        status == .interview || status == .offer
    }

    init(job: JobApplication?, prefillCompany: String = "", prefillPosition: String = "", prefillURL: String = "", prefillType: ApplicationType? = nil, prefillStatus: ApplicationStatus? = nil) {
        self.job = job
        _companyName            = State(initialValue: job?.companyName ?? prefillCompany)
        _companyLogoImageData   = State(initialValue: job?.companyLogoImageData)
        _position               = State(initialValue: job?.position ?? prefillPosition)
        _type                   = State(initialValue: job?.jobType ?? prefillType)
        _status                 = State(initialValue: job?.status ?? prefillStatus ?? .applied)
        _season                 = State(initialValue: job?.season)
        _dateApplied            = State(initialValue: job?.dateApplied ?? Date())
        _jobURL                 = State(initialValue: job?.jobURL ?? prefillURL)
        _jobNotes               = State(initialValue: job?.jobNotes ?? "")
        _resumeFileName         = State(initialValue: job?.resumeFileName)
        _resumeID               = State(initialValue: job?.resumeID)
        __pendingResumeBookmark = State(initialValue: nil)
        _compensationKind       = State(initialValue: job?.compensationKind)
        _compensationAmount     = State(initialValue: job?.compensationAmount.map { Self.formatAmount($0) } ?? "")
        _compensationCurrency   = State(initialValue: job?.compensationCurrency ?? .usd)
        _salaryPeriod           = State(initialValue: job?.salaryPeriod ?? .yearly)
        _reminderEnabled        = State(initialValue: job?.reminderEnabled ?? false)
        _reminderTime           = State(initialValue: job?.reminderTime ?? Self.defaultReminderTime)
        _companyResearch        = State(initialValue: job?.companyResearch ?? "")
        _interviewNotes         = State(initialValue: job?.interviewNotes ?? "")
    }

    private static var defaultReminderTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private static func formatAmount(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%g", value)
    }

    // MARK: - Save Bar

    @ViewBuilder
    private var saveBar: some View {
        if hasChanges || isNewApplication || !missingFields.isEmpty {
            VStack(spacing: 0) {
                Divider().opacity(0.4)
                HStack {
                    Button {
                        if !missingFields.isEmpty {
                            handleInvalidSaveTap()
                        } else if hasChanges {
                            AppHaptics.shared.medium()
                            save()
                            dismiss()
                        }
                    } label: {
                        Text(saveButtonLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background {
                                Capsule()
                                    .fill(isSaveDisabled ? Color.secondary.opacity(0.3) : Color.accentColor)
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 110)
                .background(Color(UIColor.systemBackground))
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.appSmooth, value: isSaveDisabled)
        }
    }

    private var firstMissingSection: FormSection? {
        if companyName.trimmingCharacters(in: .whitespaces).isEmpty
            || position.trimmingCharacters(in: .whitespaces).isEmpty {
            return .info
        }
        if type == nil { return .type }
        if status == nil { return .status }
        return nil
    }

    private func handleInvalidSaveTap() {
        AppHaptics.shared.warning()
        if let target = firstMissingSection {
            scrollTargetSection = target
        }
        withAnimation(.linear(duration: 0.45)) {
            shakeMissingFields = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            shakeMissingFields = false
        }
    }

    // MARK: - Body

    var body: some View {
        let shakingSection: FormSection? = shakeMissingFields ? firstMissingSection : nil

        ZStack {
            AmbientBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        JobInfoSection(
                            companyName: $companyName,
                            companyLogoImageData: $companyLogoImageData,
                            position: $position,
                            pickerItem: $pickerItem
                        )
                        .id(FormSection.info)
                        .modifier(ShakeEffect(animatableData: shakingSection == .info ? 1 : 0))
                        .changedHighlight(!isNewApplication && (companyName != job?.companyName || position != job?.position || companyLogoImageData != job?.companyLogoImageData))
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 12)
                        .animation(.appSmooth.delay(0.00), value: contentAppeared)

                        TypePickerSection(type: $type)
                            .id(FormSection.type)
                            .modifier(ShakeEffect(animatableData: shakingSection == .type ? 1 : 0))
                            .changedHighlight(!isNewApplication && type != job?.jobType)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 12)
                            .animation(.appSmooth.delay(0.03), value: contentAppeared)

                        StatusPickerSection(status: $status)
                            .id(FormSection.status)
                            .modifier(ShakeEffect(animatableData: shakingSection == .status ? 1 : 0))
                            .changedHighlight(!isNewApplication && status != job?.status)
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 12)
                            .animation(.appSmooth.delay(0.06), value: contentAppeared)

                        if isSeasonAllowed {
                            SeasonPickerSection(season: $season)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                                .changedHighlight(!isNewApplication && season != job?.season)
                                .opacity(contentAppeared ? 1 : 0)
                                .offset(y: contentAppeared ? 0 : 12)
                                .animation(.appSmooth.delay(0.09), value: contentAppeared)
                        }
                        DateAppliedSection(
                            dateApplied: Binding(
                                get: { dateApplied as Date? },
                                set: { dateApplied = $0 ?? Date() }
                            ),
                            status: status,
                            reminderEnabled: $reminderEnabled,
                            reminderTime: $reminderTime
                        )
                        .changedHighlight(!isNewApplication && (dateApplied != job?.dateApplied || reminderEnabled != job?.reminderEnabled))
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 12)
                        .animation(.appSmooth.delay(0.12), value: contentAppeared)

                        JobLinkSection(jobURL: $jobURL)
                            .changedHighlight(!isNewApplication && jobURL.trimmingCharacters(in: .whitespaces) != (job?.jobURL ?? ""))
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 12)
                            .animation(.appSmooth.delay(0.15), value: contentAppeared)

                        CompensationSection(
                            kind: $compensationKind,
                            amount: $compensationAmount,
                            currency: $compensationCurrency,
                            salaryPeriod: $salaryPeriod
                        )
                        .changedHighlight(!isNewApplication && (compensationKind != job?.compensationKind || parsedCompensationAmount != job?.compensationAmount || compensationCurrency != (job?.compensationCurrency ?? .usd) || salaryPeriod != (job?.salaryPeriod ?? .yearly)))
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 12)
                        .animation(.appSmooth.delay(0.18), value: contentAppeared)

                        ResumeSection(
                            resumes: orderedResumes,
                            attachedResume: attachedResume,
                            legacyResumeFileName: resumeID == nil ? resumeFileName : nil,
                            attachedResumeWasDeleted: attachedResumeWasDeleted,
                            onSelectResume: attachResume,
                            onViewAll: { isShowingResumeLibrary = true },
                            onPick: { isShowingDocumentPicker = true },
                            onClear: { isConfirmingResumeClear = true }
                        )
                        .changedHighlight(!isNewApplication && (resumeID != job?.resumeID))
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 12)
                        .animation(.appSmooth.delay(0.21), value: contentAppeared)

                        JobNotesSection(jobNotes: $jobNotes)
                            .changedHighlight(!isNewApplication && jobNotes != (job?.jobNotes ?? ""))
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 12)
                            .animation(.appSmooth.delay(0.24), value: contentAppeared)

                        if isInterviewStage {
                            InterviewKitSection(
                                companyResearch: $companyResearch,
                                interviewNotes: $interviewNotes
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.96, anchor: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                            ))
                            .changedHighlight(!isNewApplication && (companyResearch != (job?.companyResearch ?? "") || interviewNotes != (job?.interviewNotes ?? "")))
                            .opacity(contentAppeared ? 1 : 0)
                            .offset(y: contentAppeared ? 0 : 12)
                            .animation(.appSmooth.delay(0.27), value: contentAppeared)
                        }
                    }
                    .onChange(of: type) { _, _ in
                        if !isSeasonAllowed { season = nil }
                    }
                    .animation(.appSmooth, value: isSeasonAllowed)
                    .animation(.appSmooth, value: isInterviewStage)
                    .padding([.top, .horizontal])
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { contentAppeared = true }
                .onChange(of: scrollTargetSection) { _, target in
                    guard let target else { return }
                    withAnimation(.appSmooth) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    scrollTargetSection = nil
                }
            }
        }
        .onAppear(perform: attachDefaultResumeIfNeeded)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveBar
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            floatingNavBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    #if canImport(UIKit)
                    UIApplication.shared.dismissKeyboard()
                    #endif
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .accessibilityLabel("Dismiss keyboard")
            }
        }
        .confirmationDialog(
            "Delete this application?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteJob() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the job and cancel any pending reminders.")
        }
        .confirmationDialog(
            "Remove Attached Resume?",
            isPresented: $isConfirmingResumeClear,
            titleVisibility: .visible
        ) {
            Button("Remove Resume", role: .destructive) {
                resumeID = nil
                resumeFileName = nil
                _pendingResumeBookmark = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The resume will be detached from this application.")
        }
    }

    // MARK: - Floating Nav Bar

    private var floatingNavBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: isNewApplication ? "xmark" : "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
                    }
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(isNewApplication ? "Cancel" : "Back")

            Spacer()

            HStack(spacing: 10) {
                Button { isShowingLogoAttribution.toggle() } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(Theme.cardFill)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
                        }
                }
                .buttonStyle(PressScaleButtonStyle())
                .popover(isPresented: $isShowingLogoAttribution, arrowEdge: .top) {
                    HStack(spacing: 4) {
                        Text("Company logos from").foregroundStyle(.secondary)
                        Link("Logo.dev", destination: URL(string: "https://logo.dev")!)
                    }
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .presentationCompactAdaptation(.popover)
                }
                .accessibilityLabel("Logo attribution")

                if !isNewApplication {
                    Button { isShowingDeleteConfirmation = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.destructive)
                            .frame(width: 40, height: 40)
                            .background {
                                Circle()
                                    .fill(Theme.destructive.opacity(0.10))
                                    .overlay(Circle().strokeBorder(Theme.destructive.opacity(0.18), lineWidth: 1))
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("Delete application")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Save

    private func save() {
        let parsedAmount = parsedCompensationAmount
        let resolvedSalaryPeriod: SalaryPeriod? = compensationKind == .salary ? salaryPeriod : nil
        let wantsReminder = status == .toApply && reminderEnabled

        if let job {
            job.companyName         = companyName
            job.companyLogoImageData = companyLogoImageData
            job.position            = position
            job.jobType             = type
            job.status              = status
            job.season              = season
            job.dateApplied         = dateApplied
            job.jobURL              = jobURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : jobURL.trimmingCharacters(in: .whitespaces)
            job.jobNotes            = jobNotes
            job.resumeFileName      = resumeFileName
            job.resumeBookmark      = _pendingResumeBookmark ?? job.resumeBookmark
            job.resumeID            = resumeID
            job.compensationKind    = compensationKind
            job.compensationAmount  = parsedAmount
            job.compensationCurrency = compensationCurrency
            job.salaryPeriod        = resolvedSalaryPeriod
            job.reminderEnabled     = wantsReminder
            job.reminderTime        = wantsReminder ? reminderTime : nil
            job.companyResearch     = companyResearch.isEmpty ? nil : companyResearch
            job.interviewNotes      = interviewNotes.isEmpty  ? nil : interviewNotes

            updateReminder(for: job, wantsReminder: wantsReminder)
        } else {
            let selectedCycle = appState.selectedCycleID.flatMap { id in cycles.first { $0.id == id } }
            let newJob = JobApplication(
                companyName: companyName,
                companyLogoImageData: companyLogoImageData,
                position: position,
                jobType: type,
                status: status,
                season: season,
                cycle: selectedCycle,
                dateApplied: dateApplied,
                jobURL: jobURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : jobURL.trimmingCharacters(in: .whitespaces),
                jobNotes: jobNotes,
                resumeFileName: resumeFileName,
                resumeBookmark: _pendingResumeBookmark,
                resumeID: resumeID,
                compensationKind: compensationKind,
                compensationAmount: parsedAmount,
                compensationCurrency: compensationCurrency,
                salaryPeriod: resolvedSalaryPeriod,
                reminderEnabled: wantsReminder
            )
            newJob.companyResearch = companyResearch.isEmpty ? nil : companyResearch
            newJob.interviewNotes  = interviewNotes.isEmpty  ? nil : interviewNotes
            newJob.reminderTime = wantsReminder ? reminderTime : nil
            modelContext.insert(newJob)
            updateReminder(for: newJob, wantsReminder: wantsReminder)
        }
    }

    private func updateReminder(for job: JobApplication, wantsReminder: Bool) {
        NotificationManager.cancelReminder(id: job.reminderNotificationID)
        guard wantsReminder else {
            job.reminderNotificationID = nil
            return
        }
        let reminderDate = reminderFireDate(from: job.dateApplied)
        let title = "Time to apply"
        let bodyText = applicationReminderBody(company: job.companyName, position: job.position)
        let identifier = job.reminderNotificationID ?? UUID().uuidString
        job.reminderNotificationID = identifier
        Task {
            await NotificationManager.scheduleReminder(
                id: identifier,
                title: title,
                body: bodyText,
                date: reminderDate
            )
        }
    }

    private func reminderFireDate(from date: Date) -> Date {
        let calendar = Calendar.current
        let tc = calendar.dateComponents([.hour, .minute], from: reminderTime)
        return calendar.date(
            bySettingHour: tc.hour ?? 9,
            minute: tc.minute ?? 0,
            second: 0, of: date
        ) ?? date
    }

    private func applicationReminderBody(company: String, position: String) -> String {
        let trimmedCompany = company.trimmingCharacters(in: .whitespaces)
        let trimmedPosition = position.trimmingCharacters(in: .whitespaces)
        switch (trimmedPosition.isEmpty, trimmedCompany.isEmpty) {
        case (false, false): return "Apply for \(trimmedPosition) at \(trimmedCompany) today."
        case (false, true):  return "Apply for \(trimmedPosition) today."
        case (true, false):  return "Apply at \(trimmedCompany) today."
        case (true, true):   return "Don't forget to submit your application today."
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
        withAnimation(.appSmooth) {
            resumeID = resume.id
            resumeFileName = resume.fileName
            _pendingResumeBookmark = resume.bookmark
        }
    }

    private func attachDefaultResumeIfNeeded() {
        guard resumeID == nil, let defaultResume else { return }
        attachResume(defaultResume)

        // Persist on existing jobs so attachment counts elsewhere (e.g. Profile)
        // reflect this implicit attachment without requiring an explicit save.
        if let job {
            job.resumeID = defaultResume.id
            job.resumeFileName = defaultResume.fileName
            job.resumeBookmark = defaultResume.bookmark
        }
    }

    private func deleteJob() {
        guard let job else { return }
        NotificationManager.cancelReminder(id: job.reminderNotificationID)
        modelContext.delete(job)
        AppHaptics.shared.success()
        dismiss()
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


// MARK: - Preview

#Preview {
    NavigationStack {
        JobDetailView(job: JobApplication(
            companyName: "Meta",
            position: "Software Engineering Intern – 2026",
            dateApplied: Date()
        ))
    }
    .environment(AppState())
    .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self], inMemory: true)
}
