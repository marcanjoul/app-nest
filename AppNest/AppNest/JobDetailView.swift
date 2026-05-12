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
    @State private var _pendingResumeBookmark: Data?
    @State private var isShowingDocumentPicker = false
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
        __pendingResumeBookmark = State(initialValue: nil)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 20) {
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
                        resumeFileName: resumeFileName,
                        onPick: { isShowingDocumentPicker = true },
                        onClear: { resumeFileName = nil }
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
                    resumeFileName = picked.fileName
                    self._pendingResumeBookmark = picked.bookmark
                }
            }
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
                resumeBookmark: _pendingResumeBookmark
            ))
        }
    }
}

// MARK: - Company Info Section

private struct JobInfoSection: View {
    @Binding var companyName: String
    @Binding var companyLogoName: String
    @Binding var companyLogoImageData: Data?
    @Binding var position: String
    @Binding var pickerItem: PhotosPickerItem?

    #if canImport(UIKit)
    private var logoImage: Image {
        if let data = companyLogoImageData, let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        } else if !companyLogoName.isEmpty, UIImage(named: companyLogoName) != nil {
            return Image(companyLogoName)
        } else {
            return Image(systemName: "building.2")
        }
    }
    #else
    private var logoImage: Image { Image(companyLogoName) }
    #endif

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                logoImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 22))
                            .background(
                                Circle()
                                    .fill(Color(UIColor.systemBackground))
                                    .frame(width: 18, height: 18)
                                    .offset(x: -2, y: -2)
                            )
                            .offset(x: 4, y: 4)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
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
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DarkTheme.textPrimary)

                TextField("Company Name", text: $companyName)
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundStyle(DarkTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
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
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "calendar", title: "Date Applied")
            DatePicker(
                "",
                selection: $dateApplied,
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

// MARK: - Resume Section

private struct ResumeSection: View {
    var resumeFileName: String?
    var onPick: () -> Void
    var onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "doc.richtext", title: "Resume")

            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text(resumeFileName ?? "No file attached")
                    .foregroundStyle(resumeFileName == nil ? .secondary : .primary)
                    .font(.subheadline)
                Spacer()
                if resumeFileName != nil {
                    Button(role: .destructive, action: onClear) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                Button(action: onPick) {
                    Image(systemName: "paperclip")
                }
                .foregroundStyle(.accentColor)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                )
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

// MARK: - Notes Section

private struct JobNotesSection: View {
    @Binding var jobNotes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "square.and.pencil", title: "Notes")

            ZStack(alignment: .topLeading) {
                if jobNotes.isEmpty {
                    Text("Add notes about this application…")
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
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DarkTheme.textPrimary)
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
    .modelContainer(for: JobApplication.self, inMemory: true)
}
