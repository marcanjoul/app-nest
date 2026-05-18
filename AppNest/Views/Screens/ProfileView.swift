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

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - CSV Import UI

struct CSVImportPreviewSheet: View {
    let initialRows: [CSVImportRow]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    @State private var editingRow: CSVImportRow?
    @State private var localRows: [CSVImportRow] = []
    @State private var selectedRows = Set<UUID>()
    @State private var isAddingNewCycle = false
    @State private var newCycleName = ""
    @State private var isConfirmingDelete = false
    @State private var appearedRows = Set<UUID>()

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                if localRows.isEmpty {
                    ContentUnavailableView("No rows found", systemImage: "doc.text.magnifyingglass")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            HStack {
                                let count = localRows.count
                                Text("\(count) \(count == 1 ? "row" : "rows") found")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DarkTheme.textSecondary)
                                Spacer()
                                Button(selectedRows.count == localRows.count ? "Deselect All" : "Select All") {
                                    withAnimation(.appCrisp) {
                                        if selectedRows.count == localRows.count {
                                            selectedRows.removeAll()
                                        } else {
                                            selectedRows = Set(localRows.map(\.id))
                                        }
                                    }
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                            }
                            .padding(.horizontal, 4)
                            .padding(.bottom, 10)

                            VStack(spacing: 8) {
                                ForEach(Array($localRows.enumerated()), id: \.element.id) { index, _ in
                                    previewRow(row: $localRows[index], index: index)
                                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                                }
                            }
                            .animation(.appSmooth, value: localRows.count)

                            if localRows.contains(where: { !$0.isComplete }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 11))
                                    Text("Some rows are missing required fields. Tap a row to edit.")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(Color.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.top, 10)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import \(localRows.count)") { finalizeImport() }
                        .font(.system(size: 14, weight: .semibold))
                        .disabled(localRows.isEmpty || localRows.contains(where: { !$0.isComplete }))
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    if !selectedRows.isEmpty {
                        Button(role: .destructive) { isConfirmingDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .foregroundStyle(Color.red)

                        Spacer()

                        Menu {
                            Button { isAddingNewCycle = true } label: {
                                Label("New Cycle...", systemImage: "plus")
                            }
                            if !cycles.isEmpty {
                                Divider()
                                ForEach(cycles) { cycle in
                                    Button(cycle.name) { moveToCycle(cycle) }
                                }
                            }
                        } label: {
                            Label("Move to Cycle", systemImage: "folder")
                        }
                    }
                }
            }
            .alert("New Cycle", isPresented: $isAddingNewCycle) {
                TextField("Cycle Name", text: $newCycleName)
                Button("Create & Move") { createNewCycleAndMove() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new job search cycle.")
            }
            .confirmationDialog(
                "Delete \(selectedRows.count) Row\(selectedRows.count == 1 ? "" : "s")?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The selected row\(selectedRows.count == 1 ? "" : "s") will be removed from this import preview.")
            }
            .onAppear {
                if localRows.isEmpty { localRows = initialRows }
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

    // MARK: - Row card

    @ViewBuilder
    private func previewRow(row: Binding<CSVImportRow>, index: Int) -> some View {
        let r = row.wrappedValue
        let isSelected = selectedRows.contains(r.id)

        HStack(spacing: 12) {
            // Selection toggle
            Button {
                withAnimation(.appCrisp) {
                    if selectedRows.contains(r.id) { selectedRows.remove(r.id) }
                    else { selectedRows.insert(r.id) }
                }
                AppHaptics.shared.light()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.accentColor : DarkTheme.textTertiary)
            }
            .buttonStyle(.plain)

            // Logo
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DarkTheme.avatarGradient(for: r.companyName.isEmpty ? "?" : r.companyName))
                if let data = r.logoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    let initial = String(r.companyName.prefix(1)).uppercased()
                    Text(initial.isEmpty ? "?" : initial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Tappable content → open edit
            Button { editingRow = r } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(r.companyName.isEmpty ? "Missing Company" : r.companyName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(r.companyName.isEmpty ? .orange : DarkTheme.textPrimary)
                            .lineLimit(1)
                        Text(r.position.isEmpty ? "Missing Position" : r.position)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(r.position.isEmpty ? .orange : DarkTheme.textSecondary)
                            .lineLimit(1)
                        HStack(spacing: 5) {
                            if let status = r.status {
                                previewBadge(status.rawValue, color: status.color)
                            }
                            if let type = r.jobType {
                                previewBadge(type.rawValue, color: type.color)
                            }
                            if let cycleID = r.cycleID,
                               let cycle = cycles.first(where: { $0.id == cycleID }) {
                                previewBadge(cycle.name, color: Color.accentColor)
                            }
                        }
                    }
                    Spacer()
                    if !r.isComplete {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.system(size: 13))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DarkTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DarkTheme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor.opacity(0.4) : DarkTheme.cardBorder,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
        }
        .animation(.appCrisp, value: isSelected)
        .opacity(appearedRows.contains(r.id) ? 1 : 0)
        .offset(y: appearedRows.contains(r.id) ? 0 : 10)
        .onAppear {
            let delay = Double(min(index, 8)) * 0.045
            withAnimation(.appSmooth.delay(delay)) {
                appearedRows.insert(r.id)
            }
        }
        .task(id: r.companyName) {
            guard row.wrappedValue.logoData == nil else { return }
            let trimmed = r.companyName.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
            if let data = await LogoFetcher.fetchLogoData(for: trimmed, darkMode: colorScheme == .dark) {
                withAnimation(.appSmooth) { row.logoData.wrappedValue = data }
            }
        }
    }

    // MARK: - Badge helper

    @ViewBuilder
    private func previewBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Actions

    private func deleteSelected() {
        withAnimation(.appSmooth) {
            localRows.removeAll { selectedRows.contains($0.id) }
            selectedRows.removeAll()
        }
        AppHaptics.shared.light()
    }

    private func moveToCycle(_ cycle: JobCycle) {
        for i in localRows.indices where selectedRows.contains(localRows[i].id) {
            localRows[i].cycleID = cycle.id
        }
        selectedRows.removeAll()
        AppHaptics.shared.success()
    }

    private func createNewCycleAndMove() {
        let name = newCycleName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let cycle = JobCycle(name: name)
        modelContext.insert(cycle)
        moveToCycle(cycle)
        newCycleName = ""
    }

    private func finalizeImport() {
        let defaultCycle = cycles.first(where: { $0.id == appState.selectedCycleID })
        for row in localRows {
            let rowCycle = row.cycleID.flatMap { id in cycles.first(where: { $0.id == id }) }
            let app = JobApplication(
                companyName: row.companyName,
                companyLogoImageData: row.logoData,
                position: row.position,
                jobType: row.jobType,
                status: row.status ?? .applied,
                season: row.season,
                cycle: rowCycle ?? defaultCycle,
                dateApplied: row.dateApplied,
                jobNotes: row.notes,
                compensationKind: row.compensationKind,
                compensationAmount: row.compensationAmount,
                compensationCurrency: row.compensationCurrency,
                salaryPeriod: row.salaryPeriod
            )
            modelContext.insert(app)
        }
        try? modelContext.save()
        AppHaptics.shared.success()
        dismiss()
    }
}

struct EditImportRowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]
    @State var row: CSVImportRow
    var onSave: (CSVImportRow) -> Void
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        logoSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.appSmooth.delay(0.00), value: appeared)
                        basicInfoCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.appSmooth.delay(0.05), value: appeared)
                        typeStatusCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.appSmooth.delay(0.10), value: appeared)
                        dateCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.appSmooth.delay(0.15), value: appeared)
                        compensationCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.appSmooth.delay(0.20), value: appeared)
                        cycleCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.appSmooth.delay(0.25), value: appeared)
                        notesCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.appSmooth.delay(0.30), value: appeared)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onAppear { appeared = true }
            .navigationTitle("Edit Row")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(row)
                        AppHaptics.shared.success()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .task(id: row.companyName) {
            let trimmed = row.companyName.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if let data = await LogoFetcher.fetchLogoData(for: trimmed, darkMode: colorScheme == .dark) {
                withAnimation(.appSmooth) { row.logoData = data }
            }
        }
    }

    // MARK: - Logo

    private var logoSection: some View {
        HStack {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DarkTheme.avatarGradient(for: row.companyName.isEmpty ? "?" : row.companyName))
                if let data = row.logoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                } else {
                    let initial = String(row.companyName.prefix(1)).uppercased()
                    Text(initial.isEmpty ? "?" : initial)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            .animation(.appSmooth, value: row.logoData == nil)
            Spacer()
        }
    }

    // MARK: - Basic info

    private var basicInfoCard: some View {
        VStack(spacing: 8) {
            importFieldRow(
                icon: "building.2", label: "Company",
                text: $row.companyName, placeholder: "Company name", required: true
            )
            importFieldRow(
                icon: "briefcase", label: "Position",
                text: $row.position, placeholder: "Job title", required: true
            )
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Type / Status / Season

    private var typeStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            importPillRow(icon: "tag", label: "Job Type") {
                ForEach(ApplicationType.allCases, id: \.self) { t in
                    SelectablePill(option: t, isSelected: row.jobType == t, color: t.color, icon: t.iconName) {
                        withAnimation(.appCrisp) { row.jobType = row.jobType == t ? nil : t }
                        AppHaptics.shared.light()
                    }
                }
            }
            Divider().opacity(0.35)
            importPillRow(icon: "flag", label: "Status") {
                ForEach(ApplicationStatus.allCases, id: \.self) { s in
                    SelectablePill(option: s, isSelected: row.status == s, color: s.color, icon: s.iconName) {
                        withAnimation(.appCrisp) { row.status = row.status == s ? nil : s }
                        AppHaptics.shared.light()
                    }
                }
            }
            Divider().opacity(0.35)
            importPillRow(icon: "calendar.badge.clock", label: "Season") {
                ForEach(ApplicationSeason.allCases, id: \.self) { s in
                    SelectablePill(option: s, isSelected: row.season == s, color: s.color, icon: s.iconName) {
                        withAnimation(.appCrisp) { row.season = row.season == s ? nil : s }
                        AppHaptics.shared.light()
                    }
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Date

    private var dateCard: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(width: 14)
                Text("Date Applied")
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
            }
            Spacer()
            DatePicker("", selection: $row.dateApplied, displayedComponents: .date)
                .labelsHidden()
                .tint(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .glassCard()
    }

    // MARK: - Compensation

    private var compensationCard: some View {
        CompensationSection(
            kind: $row.compensationKind,
            amount: compensationAmountBinding,
            currency: compensationCurrencyBinding,
            salaryPeriod: salaryPeriodBinding
        )
    }

    private var compensationAmountBinding: Binding<String> {
        Binding(
            get: {
                guard let v = row.compensationAmount else { return "" }
                return v.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(v)) : String(v)
            },
            set: { row.compensationAmount = Double($0) }
        )
    }

    private var compensationCurrencyBinding: Binding<Currency> {
        Binding(
            get: { row.compensationCurrency ?? .usd },
            set: { row.compensationCurrency = $0 }
        )
    }

    private var salaryPeriodBinding: Binding<SalaryPeriod> {
        Binding(
            get: { row.salaryPeriod ?? .yearly },
            set: { row.salaryPeriod = $0 }
        )
    }

    // MARK: - Cycle

    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(width: 14)
                Text("Cycle")
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    cycleChip(name: "None", id: nil)
                    ForEach(cycles) { cycle in
                        cycleChip(name: cycle.name, id: cycle.id)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(18)
        .glassCard()
    }

    @ViewBuilder
    private func cycleChip(name: String, id: UUID?) -> some View {
        let isSelected = row.cycleID == id
        Button {
            withAnimation(.appCrisp) { row.cycleID = id }
            AppHaptics.shared.light()
        } label: {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : DarkTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.06))
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.09),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                        )
                }
        }
        .buttonStyle(.plain)
        .animation(.appCrisp, value: isSelected)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(width: 14)
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
            }
            TextField("Add notes…", text: $row.notes, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textPrimary)
                .lineLimit(3...8)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Helpers

    private func importFieldRow(
        icon: String, label: String,
        text: Binding<String>, placeholder: String, required: Bool
    ) -> some View {
        let isEmpty = required && text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isEmpty ? .orange : DarkTheme.textSecondary)
                    .frame(width: 14)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
                if isEmpty {
                    Text("· Fill in")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.85))
                }
            }
            TextField(placeholder, text: text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DarkTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isEmpty ? Color.orange.opacity(0.06) : Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isEmpty ? Color.orange.opacity(0.28) : Color.primary.opacity(0.07),
                            lineWidth: 1
                        )
                }
        }
    }

    @ViewBuilder
    private func importPillRow<Content: View>(
        icon: String, label: String,
        @ViewBuilder pills: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(width: 14)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { pills() }
                    .padding(.vertical, 2)
            }
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppState())
        .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self], inMemory: true)
}
