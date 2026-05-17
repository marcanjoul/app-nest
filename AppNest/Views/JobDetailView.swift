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
    @State private var reminderEnabled: Bool
    @State private var isShowingDeleteConfirmation = false
    @State private var shakeMissingFields = false
    @State private var scrollTargetSection: FormSection?

    private enum FormSection: Hashable {
        case info, type, status
    }

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
        _reminderEnabled        = State(initialValue: job?.reminderEnabled ?? false)
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
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            HStack {
                Button {
                    if isSaveDisabled {
                        handleInvalidSaveTap()
                    } else {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        save()
                        dismiss()
                    }
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
                                .shadow(color: isSaveDisabled ? .clear : Color.accentColor.opacity(0.27), radius: 10, y: 3)
                        }
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .animation(.easeOut(duration: 0.18), value: isSaveDisabled)
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
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
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
                            companyLogoName: $companyLogoName,
                            companyLogoImageData: $companyLogoImageData,
                            position: $position,
                            pickerItem: $pickerItem
                        )
                        .id(FormSection.info)
                        .modifier(ShakeEffect(animatableData: shakingSection == .info ? 1 : 0))

                        TypePickerSection(type: $type)
                            .id(FormSection.type)
                            .modifier(ShakeEffect(animatableData: shakingSection == .type ? 1 : 0))
                        StatusPickerSection(status: $status)
                            .id(FormSection.status)
                            .modifier(ShakeEffect(animatableData: shakingSection == .status ? 1 : 0))
                        if isSeasonAllowed {
                            SeasonPickerSection(season: $season)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity
                                ))
                        }
                        DateAppliedSection(
                            dateApplied: $dateApplied,
                            status: status,
                            reminderEnabled: $reminderEnabled
                        )
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
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isSeasonAllowed)
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: scrollTargetSection) { _, target in
                    guard let target else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .accessibilityLabel("Dismiss keyboard")
            }
            if isNewApplication {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.red)
                    }
                    .accessibilityLabel("Delete application")
                }
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
        .navigationTitle(isNewApplication ? "New Application" : "Job Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Save

    private func save() {
        let parsedAmount = parsedCompensationAmount
        let resolvedSalaryPeriod: SalaryPeriod? = compensationKind == .salary ? salaryPeriod : nil
        let wantsReminder = status == .toApply && reminderEnabled

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
            job.reminderEnabled     = wantsReminder

            updateReminder(for: job, wantsReminder: wantsReminder)
        } else {
            let newJob = JobApplication(
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
                salaryPeriod: resolvedSalaryPeriod,
                reminderEnabled: wantsReminder
            )
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
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: 9, to: startOfDay) ?? date
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
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
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
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
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

// MARK: - Shake Effect

/// Horizontal shake driven by an `animatableData` value of 0 (rest) or 1 (shaking).
/// Amplitude tapers as `(1 - t)` so the shake decays naturally rather than cutting off.
private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat = 0

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amplitude: CGFloat = 8
        let translation = amplitude * sin(animatableData * .pi * 4) * (1 - animatableData)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
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
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
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
                        withAnimation(.smooth) { proxy.scrollTo(first, anchor: .leading) }
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
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
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
                        withAnimation(.smooth) { proxy.scrollTo(first, anchor: .leading) }
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
    var status: ApplicationStatus?
    @Binding var reminderEnabled: Bool

    @State private var permissionDenied: Bool = false

    private var isToApply: Bool { status == .toApply }
    private var accent: Color { Color.accentColor }

    private var sectionTitle: String {
        isToApply ? "Date to Apply" : "Date Applied"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "calendar", title: sectionTitle)

            HStack {
                Spacer()
                if isToApply {
                    DatePicker(
                        "",
                        selection: $dateApplied,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .controlSize(.large)
                    .tint(accent)
                } else {
                    DatePicker(
                        "",
                        selection: $dateApplied,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .controlSize(.large)
                    .tint(accent)
                }
                Spacer()
            }
            .padding(.vertical, 2)

            if isToApply {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $reminderEnabled) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remind me to apply")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(DarkTheme.textPrimary)
                                Text("We'll send a notification on this date so you don't forget.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(DarkTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .tint(accent)

                    if permissionDenied {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.orange)
                            Text("Enable notifications in Settings to receive reminders.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DarkTheme.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onChange(of: reminderEnabled) { _, newValue in
                    guard newValue else { return }
                    Task {
                        let granted = await NotificationManager.requestAuthorization()
                        await MainActor.run {
                            if granted {
                                permissionDenied = false
                            } else {
                                permissionDenied = true
                                reminderEnabled = false
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isToApply)
        .animation(.easeOut(duration: 0.18), value: permissionDenied)
        .task(id: isToApply) {
            guard isToApply else { return }
            let denied = await NotificationManager.isDenied()
            await MainActor.run {
                permissionDenied = denied
                if denied { reminderEnabled = false }
            }
        }
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
