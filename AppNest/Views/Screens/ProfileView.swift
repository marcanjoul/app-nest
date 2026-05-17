import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    private static let displayNameStorageKey = "profile.displayName"
    private static let avatarStorageKey      = "profile.avatarDataBase64"

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    @AppStorage(Self.displayNameStorageKey) private var profileDisplayName: String = ""
    @AppStorage(Self.avatarStorageKey)      private var profileAvatarDataBase64: String = ""

    @State private var avatarSelection: PhotosPickerItem?
    @State private var isShowingDocumentPicker = false
    @State private var isShowingShareSheet     = false
    @State private var csvFileURL: URL?        = nil
    @State private var resumePendingDeletion: ResumeDocument?
    @State private var isShowingResumeManager  = false
    @State private var isShowingCyclePicker    = false

    @FocusState private var isNameFocused: Bool

    // MARK: - Derived

    private var cycleFilteredApplications: [JobApplication] {
        guard let id = appState.selectedCycleID else { return applications }
        return applications.filter { $0.cycle?.id == id }
    }

    private var orderedResumes: [ResumeDocument] {
        guard let def = resumes.first(where: \.isDefault) else { return resumes }
        return [def] + resumes.filter { $0.id != def.id }
    }

    private var inlineResumes: [ResumeDocument] { Array(orderedResumes.prefix(5)) }

    private var profileAvatarData: Data? {
        guard !profileAvatarDataBase64.isEmpty else { return nil }
        return Data(base64Encoded: profileAvatarDataBase64)
    }

    private var totalCount: Int { cycleFilteredApplications.count }

    private var profileInitial: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        return String(first).uppercased()
    }

    private var avatarGradientKey: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "AppNest" : trimmed
    }

    // MARK: - Pipeline data

    private let pipelineStatuses: [ApplicationStatus] = [.toApply, .applied, .interview, .offer, .rejected]

    private func count(for status: ApplicationStatus) -> Int {
        cycleFilteredApplications.filter { $0.status == status }.count
    }

    private func pipelineLabel(for status: ApplicationStatus) -> String {
        switch status {
        case .toApply:   return "To Apply"
        case .applied:   return "Applied"
        case .interview: return "Interview"
        case .offer:     return "Offers"
        case .rejected:  return "Rejected"
        }
    }

    private var pipelineSegments: [PipelineSegmentedBar.Segment] {
        pipelineStatuses.map { PipelineSegmentedBar.Segment(id: $0, count: count(for: $0)) }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 0) {
                    identitySection

                    VStack(spacing: 14) {
                        pipelineSection
                        resumeSection
                        exportRow
                        importRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
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
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            ProfileDocumentPicker { result in
                if case .success(let picked) = result {
                    savePickedResume(fileName: picked.fileName, bookmark: picked.bookmark)
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let url = csvFileURL { ShareSheet(activityItems: [url]) }
        }
        .alert("Delete Resume?", isPresented: deletionAlertBinding, presenting: resumePendingDeletion) { resume in
            Button("Cancel", role: .cancel) { resumePendingDeletion = nil }
            Button("Delete", role: .destructive) { deleteResume(resume) }
        } message: { resume in
            let count = attachmentCount(for: resume)
            if count > 0 {
                Text("This resume is attached to \(count) job application\(count == 1 ? "" : "s"). Deleting it will remove it from those applications.")
            } else {
                Text("")
            }
        }
        .sheet(isPresented: $isShowingResumeManager) {
            ResumeManagerSheet(
                resumes: orderedResumes,
                attachmentCount: attachmentCount,
                onSetDefault: setDefaultResume,
                onRequestDelete: { resumePendingDeletion = $0 },
                onUpload: { isShowingDocumentPicker = true }
            )
        }
        .sheet(isPresented: $isShowingCyclePicker) {
            NavigationStack { CyclePickerSheet(isPresented: $isShowingCyclePicker) }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: avatarSelection) { _, newValue in
            guard let newValue else { return }
            Task { await updateProfileAvatar(from: newValue) }
        }
        .fileImporter(
            isPresented: Binding(
                get: { appState.isImportingCSV },
                set: { appState.isImportingCSV = $0 }
            ),
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importCSV(at: url)
                }
            case .failure(let error):
                print("CSV Import failed: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: Binding(
            get: { appState.isShowingImportPreview },
            set: { appState.isShowingImportPreview = $0 }
        )) {
            CSVImportPreviewSheet()
                .environment(appState)
        }
    }

    // MARK: - Identity header

    private var identitySection: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $avatarSelection, matching: .images) {
                avatarView
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                    .overlay(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 26, height: 26)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: Color.accentColor.opacity(0.28), radius: 4, y: 2)
                        .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(.plain)
            .contextMenu {
                if profileAvatarData != nil {
                    Button(role: .destructive) {
                        profileAvatarDataBase64 = ""
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }

            VStack(spacing: 8) {
                TextField(
                    "",
                    text: $profileDisplayName,
                    prompt: Text("Your Name").foregroundColor(DarkTheme.textSecondary)
                )
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(DarkTheme.textPrimary)
                .tint(.accentColor)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isNameFocused)
                .frame(maxWidth: 260)

                if !cycles.isEmpty {
                    profileCycleChip
                }

                Text("\(totalCount) application\(totalCount == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DarkTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var avatarView: some View {
        #if canImport(UIKit)
        if let data = profileAvatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            initialAvatar
        }
        #else
        initialAvatar
        #endif
    }

    @ViewBuilder
    private var initialAvatar: some View {
        ZStack {
            DarkTheme.avatarGradient(for: avatarGradientKey)
            if profileInitial.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
            } else {
                Text(profileInitial)
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Cycle chip

    private var profileCycleChip: some View {
        Button { isShowingCyclePicker = true } label: {
            HStack(spacing: 5) {
                Image(systemName: appState.selectedCycleID != nil ? "tray.fill" : "tray.2.fill")
                    .font(.system(size: 10, weight: .semibold))
                Group {
                    if let id = appState.selectedCycleID,
                       let cycle = cycles.first(where: { $0.id == id }) {
                        Text(cycle.name)
                    } else {
                        Text("All Applications")
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(appState.selectedCycleID != nil ? Color.accentColor : DarkTheme.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(appState.selectedCycleID != nil ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.07))
                    .overlay(Capsule().strokeBorder(
                        appState.selectedCycleID != nil ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    ))
            )
        }
        .buttonStyle(.plain)
        .animation(.appCrisp, value: appState.selectedCycleID)
    }

    // MARK: - Pipeline

    private var pipelineSection: some View {
        NavigationLink(destination: ProfileStatsView()) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Pipeline")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DarkTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DarkTheme.textSecondary.opacity(0.6))
                }

                PipelineSegmentedBar(segments: pipelineSegments, total: totalCount)

                HStack(spacing: 0) {
                    ForEach(pipelineStatuses, id: \.self) { status in
                        let c = count(for: status)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(c)")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(c > 0 ? DarkTheme.textPrimary : DarkTheme.textTertiary)
                            Text(pipelineLabel(for: status))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(
                                    c > 0
                                        ? DarkTheme.statusStyle(for: status).tintColor
                                        : DarkTheme.textTertiary
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(18)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resume Section

    private var resumeSection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Resumes", systemImage: "doc.richtext")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                Spacer()
            }

            if resumes.isEmpty {
                HStack {
                    Spacer()
                    ResumePill(title: "Upload Resume", style: .add, isLarge: true) {
                        isShowingDocumentPicker = true
                    }
                    Spacer()
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(inlineResumes, id: \.id) { resume in
                        HStack(spacing: 10) {
                            ResumePill(title: resume.fileName, style: .resume, isLarge: true)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                setDefaultResume(resume)
                            } label: {
                                Image(systemName: resume.isDefault ? "star.fill" : "star")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(resume.isDefault ? Color.yellow : DarkTheme.textTertiary)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.primary.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(resume.isDefault ? "Default resume" : "Set as default resume")

                            Button(role: .destructive) {
                                resumePendingDeletion = resume
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.red)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.red.opacity(0.10)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete resume")
                        }
                    }

                    HStack(spacing: 14) {
                        Button { isShowingDocumentPicker = true } label: {
                            Label("Add Resume", systemImage: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)

                        if resumes.count > 5 {
                            Text("·")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DarkTheme.textTertiary)
                            Button { isShowingResumeManager = true } label: {
                                Label("View All", systemImage: "tray.full")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Export row

    private var exportRow: some View {
        let empty = cycleFilteredApplications.isEmpty
        return Button { exportCSV() } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(empty ? DarkTheme.textTertiary : Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(
                        empty ? Color.primary.opacity(0.06) : Color.accentColor.opacity(0.12)
                    ))

                Text("Export as CSV")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(empty ? DarkTheme.textSecondary : DarkTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DarkTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(DarkTheme.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                            .strokeBorder(DarkTheme.cardBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .disabled(empty)
        .opacity(empty ? 0.45 : 1)
    }

    private var importRow: some View {
        Button { appState.isImportingCSV = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.accentColor.opacity(0.12)))

                Text("Import CSV")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DarkTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(DarkTheme.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                            .strokeBorder(DarkTheme.cardBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { resumePendingDeletion != nil },
            set: { if !$0 { resumePendingDeletion = nil } }
        )
    }

    private func attachmentCount(for resume: ResumeDocument) -> Int {
        applications.filter { $0.resumeID == resume.id }.count
    }

    private func setDefaultResume(_ selectedResume: ResumeDocument) {
        for resume in resumes {
            resume.isDefault = resume.id == selectedResume.id
        }
    }

    private func savePickedResume(fileName: String, bookmark: Data) {
        if let existing = resumes.first(where: { $0.fileName == fileName }) {
            existing.bookmark = bookmark
            if !resumes.contains(where: \.isDefault) { setDefaultResume(existing) }
            return
        }
        let resume = ResumeDocument(
            fileName: fileName,
            bookmark: bookmark,
            isDefault: resumes.isEmpty || !resumes.contains(where: \.isDefault)
        )
        modelContext.insert(resume)
    }

    private func deleteResume(_ resume: ResumeDocument) {
        let wasDefault = resume.isDefault
        modelContext.delete(resume)
        resumePendingDeletion = nil
        if wasDefault, let replacement = resumes.first(where: { $0.id != resume.id }) {
            replacement.isDefault = true
        }
    }

    private func updateProfileAvatar(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            profileAvatarDataBase64 = data.base64EncodedString()
        }
    }

    private func importCSV(at url: URL) {
        let _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            let rows = CSVImporter.parse(data)
            if rows.isEmpty {
                // In a real app, show an alert. For now, just print.
                print("No rows found in CSV.")
                return
            }
            appState.csvImportPreview = rows
            appState.isShowingImportPreview = true
        } catch {
            print("Failed to read CSV: \(error)")
        }
    }

    // MARK: - CSV Export

    private func exportCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let header = "Company,Position,Type,Status,Season,Date Applied,Compensation,Currency,Resume,Notes\n"
        let rows = cycleFilteredApplications
            .sorted { $0.dateApplied > $1.dateApplied }
            .map { app -> String in
                let compensation: String = {
                    guard let amount = app.compensationAmount else { return "" }
                    let kind = app.compensationKind?.rawValue ?? ""
                    let period = app.salaryPeriod.map { "/\($0.rawValue)" } ?? ""
                    return "\(amount)\(period.isEmpty ? " \(kind)" : " \(kind)\(period)")"
                }()
                let fields = [
                    escapeCSV(app.companyName),
                    escapeCSV(app.position),
                    escapeCSV(app.jobType?.rawValue ?? ""),
                    escapeCSV(app.status?.rawValue ?? ""),
                    escapeCSV(app.season?.rawValue ?? ""),
                    escapeCSV(dateFormatter.string(from: app.dateApplied)),
                    escapeCSV(compensation),
                    escapeCSV(app.compensationAmount != nil ? (app.compensationCurrency?.rawValue ?? "") : ""),
                    escapeCSV(app.resumeFileName ?? ""),
                    escapeCSV(app.jobNotes ?? "")
                ]
                return fields.joined(separator: ",")
            }

        let csv = header + rows.joined(separator: "\n") + "\n"
        let datestamp = dateFormatter.string(from: Date())
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppNest_Export_\(datestamp).csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            csvFileURL = tempURL
            isShowingShareSheet = true
        } catch {
            print("CSV export failed: \(error)")
        }
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}

// MARK: - Pipeline Segmented Bar

private struct PipelineSegmentedBar: View {
    struct Segment: Identifiable {
        let id: ApplicationStatus
        let count: Int
        var color: Color { DarkTheme.statusStyle(for: id).tintColor }
    }

    let segments: [Segment]
    let total: Int

    private var active: [Segment] { segments.filter { $0.count > 0 } }

    var body: some View {
        if total == 0 || active.isEmpty {
            Capsule()
                .fill(Color.primary.opacity(0.07))
                .frame(maxWidth: .infinity)
                .frame(height: 8)
        } else {
            GeometryReader { geo in
                let spacing: CGFloat = 2
                let available = geo.size.width - spacing * CGFloat(active.count - 1)
                HStack(spacing: spacing) {
                    ForEach(active.indices, id: \.self) { i in
                        active[i].color
                            .frame(width: max(6, available * CGFloat(active[i].count) / CGFloat(total)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Resume Manager Sheet

private struct ResumeManagerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let resumes: [ResumeDocument]
    let attachmentCount: (ResumeDocument) -> Int
    let onSetDefault: (ResumeDocument) -> Void
    let onRequestDelete: (ResumeDocument) -> Void
    let onUpload: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(resumes, id: \.id) { resume in
                            row(for: resume)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("All Resumes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: onUpload)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .accessibilityLabel("Upload resume")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func row(for resume: ResumeDocument) -> some View {
        HStack(spacing: 10) {
            ResumePill(title: resume.fileName, style: .resume, isLarge: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button { onSetDefault(resume) } label: {
                Image(systemName: resume.isDefault ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(resume.isDefault ? Color.yellow : DarkTheme.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .disabled(resume.isDefault)
            .accessibilityLabel(resume.isDefault ? "Default resume" : "Set as default")

            Button(role: .destructive) { onRequestDelete(resume) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.red.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete resume")
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

// MARK: - Document Picker

private struct ProfileDocumentPicker: UIViewControllerRepresentable {
    struct PickedFile { let fileName: String; let bookmark: Data }
    var completion: (Result<PickedFile, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .plainText, .rtf, .data], asCopy: true
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

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - CSV Import UI

private struct CSVImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    @State private var editingRow: CSVImportRow?
    @State private var localRows: [CSVImportRow] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                
                if localRows.isEmpty {
                    ContentUnavailableView("No rows found", systemImage: "doc.text.magnifyingglass")
                } else {
                    List {
                        Section {
                            ForEach(localRows) { row in
                                Button {
                                    editingRow = row
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(row.companyName.isEmpty ? "Missing Company" : row.companyName)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(row.companyName.isEmpty ? Color.red : DarkTheme.textPrimary)
                                            
                                            Text(row.position.isEmpty ? "Missing Position" : row.position)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(row.position.isEmpty ? Color.red : DarkTheme.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if !row.isComplete {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(Color.orange)
                                                .font(.system(size: 14))
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(DarkTheme.textTertiary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { indices in
                                localRows.remove(atOffsets: indices)
                            }
                        } header: {
                            Text("\(localRows.count) rows found")
                        } footer: {
                            if localRows.contains(where: { !$0.isComplete }) {
                                Text("Some rows are missing required fields (Company or Position). Tap to edit.")
                                    .foregroundStyle(Color.orange)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import All") {
                        finalizeImport()
                    }
                    .disabled(localRows.isEmpty || localRows.contains(where: { !$0.isComplete }))
                }
            }
            .onAppear {
                if let preview = appState.csvImportPreview {
                    localRows = preview
                }
            }
            .sheet(item: $editingRow) { row in
                EditImportRowView(row: row) { updated in
                    if let index = localRows.firstIndex(where: { $0.id == updated.id }) {
                        localRows[index] = updated
                    }
                }
            }
        }
    }

    private func finalizeImport() {
        let cycle = cycles.first(where: { $0.id == appState.selectedCycleID })
        
        for row in localRows {
            let app = JobApplication(
                companyName: row.companyName,
                position: row.position,
                jobType: row.jobType,
                status: row.status ?? .applied,
                season: row.season,
                cycle: cycle,
                dateApplied: row.dateApplied,
                jobNotes: row.notes,
                compensationKind: row.compensationKind,
                compensationAmount: row.compensationAmount,
                compensationCurrency: row.compensationCurrency,
                salaryPeriod: row.salaryPeriod
            )
            modelContext.insert(app)
        }
        
        appState.csvImportPreview = nil
        dismiss()
    }
}

private struct EditImportRowView: View {
    @Environment(\.dismiss) private var dismiss
    @State var row: CSVImportRow
    var onSave: (CSVImportRow) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Company Name", text: $row.companyName)
                    TextField("Position", text: $row.position)
                }
                
                Section("Status & Type") {
                    Picker("Type", selection: $row.jobType) {
                        Text("Not Set").tag(nil as ApplicationType?)
                        ForEach(ApplicationType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t as ApplicationType?)
                        }
                    }
                    
                    Picker("Status", selection: $row.status) {
                        Text("Not Set").tag(nil as ApplicationStatus?)
                        ForEach(ApplicationStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s as ApplicationStatus?)
                        }
                    }
                    
                    Picker("Season", selection: $row.season) {
                        Text("Not Set").tag(nil as ApplicationSeason?)
                        ForEach(ApplicationSeason.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s as ApplicationSeason?)
                        }
                    }
                }
                
                Section("Date") {
                    DatePicker("Applied On", selection: $row.dateApplied, displayedComponents: .date)
                }
                
                Section("Compensation") {
                    HStack {
                        TextField("Amount", value: $row.compensationAmount, format: .number)
                            .keyboardType(.decimalPad)
                        
                        Picker("", selection: $row.compensationCurrency) {
                            ForEach(Currency.allCases, id: \.self) { c in
                                Text(c.rawValue).tag(c as Currency?)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    
                    Picker("Kind", selection: $row.compensationKind) {
                        Text("Not Set").tag(nil as CompensationKind?)
                        ForEach(CompensationKind.allCases, id: \.self) { k in
                            Text(k.rawValue).tag(k as CompensationKind?)
                        }
                    }
                    
                    if row.compensationKind == .salary {
                        Picker("Period", selection: $row.salaryPeriod) {
                            Text("Not Set").tag(nil as SalaryPeriod?)
                            ForEach(SalaryPeriod.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p as SalaryPeriod?)
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes", text: $row.notes, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .navigationTitle("Edit Row")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(row)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppState())
        .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self], inMemory: true)
}
