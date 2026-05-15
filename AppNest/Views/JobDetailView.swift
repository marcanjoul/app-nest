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
    @State private var isShowingDocumentPicker = false
    @State private var isShowingResumeLibrary = false
    @State private var pickerItem: PhotosPickerItem? = nil

    private var isNewApplication: Bool { job == nil }

    private var isSaveDisabled: Bool {
        companyName.trimmingCharacters(in: .whitespaces).isEmpty ||
        position.trimmingCharacters(in: .whitespaces).isEmpty ||
        type == nil || status == nil
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
                    SeasonPickerSection(season: $season)
                    DateAppliedSection(dateApplied: $dateApplied)
                    ResumeSection(
                        resumes: orderedResumes,
                        attachedResume: attachedResume,
                        legacyResumeFileName: resumeID == nil ? resumeFileName : nil,
                        attachedResumeWasDeleted: attachedResumeWasDeleted,
                        onSelectResume: attachResume,
                        onViewAll: { isShowingResumeLibrary = true },
                        onPick: { isShowingDocumentPicker = true },
                        onClear: {
                            resumeID = nil
                            resumeFileName = nil
                            _pendingResumeBookmark = nil
                        }
                    )
                    JobNotesSection(jobNotes: $jobNotes)
                }
                .onChange(of: type) { _, newType in
                    let allowed: [ApplicationType] = [.partTime, .internship, .temporary, .Co_op]
                    if !(newType.map { allowed.contains($0) } ?? false) { season = nil }
                }
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
                resumeID: resumeID
            ))
        }
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

// MARK: - Company Info Section

private struct JobInfoSection: View {
    @Binding var companyName: String
    @Binding var companyLogoName: String
    @Binding var companyLogoImageData: Data?
    @Binding var position: String
    @Binding var pickerItem: PhotosPickerItem?

    private enum Field: Hashable { case position, company }
    @FocusState private var focused: Field?

    private static let tintPalette: [Color] = [
        Color(red: 0.36, green: 0.66, blue: 0.96),
        Color(red: 0.96, green: 0.73, blue: 0.28),
        Color(red: 0.30, green: 0.80, blue: 0.45),
        Color(red: 0.93, green: 0.38, blue: 0.44),
        Color(red: 0.62, green: 0.52, blue: 0.96),
        Color(red: 0.96, green: 0.52, blue: 0.62),
    ]

    private var accentTint: Color {
        let trimmed = companyName.trimmingCharacters(in: .whitespaces)
        let key: String
        if let first = trimmed.first {
            key = String(first).uppercased()
        } else {
            key = "AppNest"
        }
        return Self.tintPalette[abs(key.hashValue) % Self.tintPalette.count]
    }

    #if canImport(UIKit)
    private var logoImage: Image? {
        if let data = companyLogoImageData, let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        } else if !companyLogoName.isEmpty, UIImage(named: companyLogoName) != nil {
            return Image(companyLogoName)
        }
        return nil
    }
    #else
    private var logoImage: Image? {
        companyLogoName.isEmpty ? nil : Image(companyLogoName)
    }
    #endif

    private var logoInitial: String {
        let trimmed = companyName.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    private let titleBaseFontSize: CGFloat = 22
    private let companyBaseFontSize: CGFloat = 12

    @ViewBuilder
    private func editableFieldBackground(isFocused: Bool, tint: Color? = nil) -> some View {
        let strokeColor: Color = isFocused
            ? (tint ?? Color.accentColor).opacity(0.55)
            : Color.primary.opacity(0.12)
        Capsule(style: .continuous)
            .fill(Color.primary.opacity(isFocused ? 0.08 : 0.04))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }

    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Group {
                    if let image = logoImage {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [accentTint, accentTint.opacity(0.72)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                            Text(logoInitial)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.20), radius: 10, y: 5)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 24, height: 24)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(accentTint))
                    }
                    .offset(x: 2, y: 2)
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        companyLogoImageData = data
                    }
                }
            }
            .contextMenu {
                if companyLogoImageData != nil {
                    Button(role: .destructive) { companyLogoImageData = nil } label: {
                        Label("Remove Custom Logo", systemImage: "trash")
                    }
                }
            }

            VStack(spacing: 6) {
                TextField("Position Title", text: $position)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .truncationMode(.tail)
                    .font(.system(size: titleBaseFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(DarkTheme.textPrimary)
                    .focused($focused, equals: .position)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        editableFieldBackground(isFocused: focused == .position)
                    )

                TextField("COMPANY NAME", text: $companyName)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .truncationMode(.tail)
                    .font(.system(size: companyName.isEmpty ? companyBaseFontSize * 0.85 : companyBaseFontSize, weight: .medium, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(DarkTheme.textPrimary.opacity(0.6))
                    .textInputAutocapitalization(.words)
                    .focused($focused, equals: .company)
                    .frame(maxWidth: 220)
                    .padding(.horizontal, companyName.isEmpty ? 10 : 12)
                    .padding(.vertical, companyName.isEmpty ? 4 : 6)
                    .background(
                        editableFieldBackground(isFocused: focused == .company)
                    )
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
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
            SectionLabel(icon: "list.bullet", title: "Job Type")

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
            SectionLabel(icon: "rectangle.and.hand.point.up.left.fill", title: "Status")

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

// MARK: - Resume Section

private struct ResumeSection: View {
    var resumes: [ResumeDocument]
    var attachedResume: ResumeDocument?
    var legacyResumeFileName: String?
    var attachedResumeWasDeleted: Bool
    var onSelectResume: (ResumeDocument) -> Void
    var onViewAll: () -> Void
    var onPick: () -> Void
    var onClear: () -> Void

    private var inlineResumes: [ResumeDocument] {
        guard let attachedResume, !resumes.prefix(3).contains(where: { $0.id == attachedResume.id }) else {
            return Array(resumes.prefix(3))
        }

        return [attachedResume] + resumes.filter { $0.id != attachedResume.id }.prefix(2)
    }

    private var isShowingUploadOnly: Bool {
        resumes.isEmpty &&
        attachedResume == nil &&
        legacyResumeFileName == nil &&
        !attachedResumeWasDeleted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "doc.richtext", title: "Resume")

            if isShowingUploadOnly {
                ResumePill(title: "Upload Resume", style: .add, isSelected: true, showsGlow: false, action: onPick)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(inlineResumes, id: \.id) { resume in
                                let isAttached = attachedResume?.id == resume.id
                                ResumePill(
                                    title: resume.fileName,
                                    style: isAttached ? .attached : .resume,
                                    isSelected: isAttached,
                                    isDefault: resume.isDefault,
                                    action: { onSelectResume(resume) }
                                )
                            }

                            if let legacyResumeFileName {
                                ResumePill(title: legacyResumeFileName, style: .attached, isSelected: true)
                            }

                            if attachedResumeWasDeleted {
                                ResumePill(title: "File Deleted", style: .deleted)
                            }

                            ResumePill(title: "Add Resume", style: .add, action: onPick)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }

                    HStack(spacing: 8) {
                        if resumes.count > inlineResumes.count {
                            Button(action: onViewAll) {
                                Label("View All", systemImage: "tray.full")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        if attachedResume != nil || legacyResumeFileName != nil || attachedResumeWasDeleted {
                            Button(action: onPick) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.accentColor.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Replace resume")

                            Button(role: .destructive, action: onClear) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.red)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.red.opacity(0.10)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove attached resume")
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

private struct ResumeLibrarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let resumes: [ResumeDocument]
    let attachedResumeID: UUID?
    let onSelectResume: (ResumeDocument) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(resumes, id: \.id) { resume in
                            let isAttached = attachedResumeID == resume.id
                            Button {
                                onSelectResume(resume)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: resume.isDefault ? "star.fill" : "doc.text.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(resume.isDefault ? Color(red: 0.96, green: 0.73, blue: 0.28) : DarkTheme.textSecondary)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.primary.opacity(0.06)))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(resume.fileName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(DarkTheme.textPrimary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)

                                        if resume.isDefault {
                                            Text("Default")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color(red: 0.96, green: 0.73, blue: 0.28))
                                        }
                                    }

                                    Spacer()

                                    if isAttached {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(Color(red: 0.30, green: 0.80, blue: 0.45))
                                    }
                                }
                                .padding(14)
                                .background {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isAttached ? Color(red: 0.30, green: 0.80, blue: 0.45).opacity(0.12) : Color.primary.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(
                                                    isAttached ? Color(red: 0.30, green: 0.80, blue: 0.45).opacity(0.35) : Color.primary.opacity(0.08),
                                                    lineWidth: 1
                                                )
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

// MARK: - Section Label Helper

private struct SectionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DarkTheme.textSecondary)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(DarkTheme.textSecondary)
        }
    }
}

// MARK: - Document Picker

private struct DocumentPicker: UIViewControllerRepresentable {
    struct PickedFile { let fileName: String; let bookmark: Data }
    var completion: (Result<PickedFile, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .plainText, .rtf, .image, .data], asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<PickedFile, Error>) -> Void
        init(completion: @escaping (Result<PickedFile, Error>) -> Void) { self.completion = completion }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            do {
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                completion(.success(PickedFile(fileName: url.lastPathComponent, bookmark: bookmark)))
            } catch { completion(.failure(error)) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
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
