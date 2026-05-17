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
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]

    @AppStorage(Self.displayNameStorageKey) private var profileDisplayName: String = ""
    @AppStorage(Self.avatarStorageKey)      private var profileAvatarDataBase64: String = ""

    @State private var avatarSelection: PhotosPickerItem?
    @State private var isShowingDocumentPicker = false
    @State private var isShowingShareSheet     = false
    @State private var csvFileURL: URL?        = nil
    @State private var resumePendingDeletion: ResumeDocument?
    @State private var isShowingResumeManager  = false

    @FocusState private var isNameFocused: Bool

    // MARK: - Derived

    private var orderedResumes: [ResumeDocument] {
        guard let def = resumes.first(where: \.isDefault) else { return resumes }
        return [def] + resumes.filter { $0.id != def.id }
    }

    private var inlineResumes: [ResumeDocument] {
        Array(orderedResumes.prefix(5))
    }

    private var profileAvatarData: Data? {
        guard !profileAvatarDataBase64.isEmpty else { return nil }
        return Data(base64Encoded: profileAvatarDataBase64)
    }

    private var totalCount: Int { applications.count }

    private var activeCount: Int {
        applications.filter { $0.status == .applied || $0.status == .interview }.count
    }

    private var offerCount: Int {
        applications.filter { $0.status == .offer }.count
    }

    private var profileInitial: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        return String(first).uppercased()
    }

    private var avatarGradientKey: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "AppNest" : trimmed
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 18) {
                    identitySection
                    insightsCard
                    resumeSection
                    exportSection
                }
                .padding()
                .padding(.bottom, 12)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
            Button("Cancel", role: .cancel) {
                resumePendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                deleteResume(resume)
            }
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
        .onChange(of: avatarSelection) { _, newValue in
            guard let newValue else { return }
            Task { await updateProfileAvatar(from: newValue) }
        }
    }

    // MARK: - Identity (branded hero)

    private var identitySection: some View {
        VStack(spacing: 18) {
            PhotosPicker(selection: $avatarSelection, matching: .images) {
                avatarView
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
                    .overlay(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 30, height: 30)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .shadow(color: .black.opacity(0.20), radius: 3, y: 1)
                        .offset(x: 4, y: 4)
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

            TextField(
                "",
                text: $profileDisplayName,
                prompt: Text("Add Your Name")
                    .foregroundColor(.white.opacity(0.55))
            )
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .tint(.white)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($isNameFocused)
            .frame(maxWidth: 280)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(.white.opacity(isNameFocused ? 0.15 : 0))
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.accentColor.opacity(0.30), radius: 18, y: 8)
    }

    @ViewBuilder
    private var heroBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor,
                    Color.accentColor.opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [.white.opacity(0.20), .clear],
                startPoint: .top,
                endPoint: .center
            )
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 240, height: 240)
                .offset(x: -130, y: -110)
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 200, height: 200)
                .offset(x: 140, y: 110)
        }
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
            LinearGradient(
                colors: [
                    Color.white.opacity(0.32),
                    Color.white.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if profileInitial.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            } else {
                Text(profileInitial)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Insights

    private var insightsCard: some View {
        NavigationLink {
            ProfileStatsView()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Label("Insights", systemImage: "chart.bar.xaxis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DarkTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(totalCount)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(totalCount == 1 ? "Application" : "Applications")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DarkTheme.textSecondary)
                }

                HStack(spacing: 8) {
                    InsightPill(
                        count: activeCount,
                        label: "Active",
                        tint: Color(red: 0.35, green: 0.65, blue: 0.96),
                        icon: "paperplane.fill"
                    )
                    InsightPill(
                        count: offerCount,
                        label: offerCount == 1 ? "Offer" : "Offers",
                        tint: Color(red: 0.30, green: 0.80, blue: 0.45),
                        icon: "checkmark.seal.fill"
                    )
                    Spacer(minLength: 0)
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.14),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resume Section (restored original look)

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

    // MARK: - Export

    private var exportSection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Export Data", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                Spacer()
            }

            Button { exportCSV() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(applications.isEmpty ? DarkTheme.textTertiary : Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle().fill(
                                applications.isEmpty
                                    ? Color.primary.opacity(0.06)
                                    : Color.accentColor.opacity(0.12)
                            )
                        )

                    Text("Export as CSV")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(applications.isEmpty ? DarkTheme.textSecondary : DarkTheme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DarkTheme.textTertiary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .disabled(applications.isEmpty)
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
            if !resumes.contains(where: \.isDefault) {
                setDefaultResume(existing)
            }
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

    // MARK: - CSV Export

    private func exportCSV() {
        var csv = "Company,Position,Type,Status,Season,Date Applied,Notes\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        for app in applications {
            let fields = [
                escapeCSV(app.companyName),
                escapeCSV(app.position),
                escapeCSV(app.jobType?.rawValue ?? ""),
                escapeCSV(app.status?.rawValue ?? ""),
                escapeCSV(app.season?.rawValue ?? ""),
                escapeCSV(dateFormatter.string(from: app.dateApplied)),
                escapeCSV(app.jobNotes ?? "")
            ]
            csv += fields.joined(separator: ",") + "\n"
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppNest_Export.csv")
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

// MARK: - Insight Pill

private struct InsightPill: View {
    let count: Int
    let label: String
    let tint: Color
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(DarkTheme.textPrimary)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DarkTheme.textSecondary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.8))
        )
    }
}

// MARK: - Resume Manager Sheet

/// Full-list resume management surface presented from the Profile resumes "View All" button.
/// Mirrors the inline row UI: per-resume star-as-default and trash-to-delete actions.
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

#Preview {
    NavigationStack { ProfileView() }
        .modelContainer(for: [JobApplication.self, ResumeDocument.self], inMemory: true)
}
