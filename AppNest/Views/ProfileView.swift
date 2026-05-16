import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    private static let displayNameStorageKey = "profile.displayName"
    private static let avatarStorageKey = "profile.avatarDataBase64"

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]

    @AppStorage(Self.displayNameStorageKey) private var profileDisplayName: String = ""
    @AppStorage(Self.avatarStorageKey) private var profileAvatarDataBase64: String = ""

    @State private var avatarSelection: PhotosPickerItem?
    @State private var isShowingDocumentPicker = false
    @State private var isShowingShareSheet     = false
    @State private var csvFileURL: URL?        = nil
    @State private var resumePendingDeletion: ResumeDocument?
    @State private var isShowingResumeManager  = false

    private var orderedResumes: [ResumeDocument] {
        guard let def = resumes.first(where: \.isDefault) else { return resumes }
        return [def] + resumes.filter { $0.id != def.id }
    }

    private var inlineResumes: [ResumeDocument] {
        Array(orderedResumes.prefix(5))
    }

    private var profileAvatarData: Data? {
        Data(base64Encoded: profileAvatarDataBase64)
    }

    private var companyCount: Int {
        Set(applications.map { $0.companyName }).count
    }

    private var activeApplicationCount: Int {
        applications.filter { $0.status == .applied || $0.status == .interview }.count
    }

    private var interviewCount: Int {
        applications.filter { $0.status == .interview }.count
    }

    private var profileTrackingSummary: String {
        guard !applications.isEmpty else {
            return "Start tracking applications to see your profile stats here."
        }

        let resumeLabel = resumes.isEmpty ? "no resumes" : "\(resumes.count) resume\(resumes.count == 1 ? "" : "s")"
        return "Tracking \(applications.count) applications across \(companyCount) companies with \(resumeLabel)."
    }

    private var appVersionFooter: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        let name = info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String ?? "AppNest"
        return "\(name) v\(version) (\(build))"
    }

    private var insightTitleCount: String {
        "\(applications.count) tracked"
    }

    private var interviewRateText: String {
        percentageString(interviewCount, over: applications.count)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 18) {
                    identitySection
                    insightsSection
                    resumeSection
                    exportSection
                }
                .padding()
            }
        }
        .navigationTitle("Profile")
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
        .onChange(of: avatarSelection) { newValue in
            guard let newValue else { return }
            Task {
                await updateProfileAvatar(from: newValue)
            }
        }
    }

    // MARK: - Identity

    private var identitySection: some View {
        VStack(spacing: 16) {
            SectionLabel(icon: "person.crop.circle.fill", title: "Identity")

            HStack(alignment: .center, spacing: 14) {
                PhotosPicker(selection: $avatarSelection, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        profileAvatarView

                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 26, height: 26)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                    }
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Your name", text: $profileDisplayName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DarkTheme.textPrimary)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    Text(profileTrackingSummary)
                        .font(.footnote)
                        .foregroundStyle(DarkTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(profileDisplayName.isEmpty ? "Edit name and photo to personalize this screen." : "Tap the avatar to update your photo.")
                        .font(.caption)
                        .foregroundStyle(DarkTheme.textTertiary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .glassCard()
    }

    private var profileAvatarView: some View {
        ZStack {
#if canImport(UIKit)
            if let data = profileAvatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackAvatar
            }
#else
            fallbackAvatar
#endif
        }
        .frame(width: 78, height: 78)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }

    @ViewBuilder
    private var fallbackAvatar: some View {
        Text(profileInitial)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DarkTheme.avatarGradient(for: profileDisplayName.isEmpty ? "AppNest" : profileDisplayName))
    }

    private var profileInitial: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "A" }
        return String(first).uppercased()
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(spacing: 14) {
            SectionLabel(icon: "chart.bar.xaxis", title: "Insights")

            NavigationLink {
                ProfileStatsView()
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(insightTitleCount)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(DarkTheme.textPrimary)

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DarkTheme.textTertiary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ProfileMetricTile(
                            title: "Active",
                            value: "\(activeApplicationCount)",
                            systemImage: "hourglass.badge.plus",
                            tint: Color(red: 0.35, green: 0.65, blue: 0.96),
                            subtitle: "Applied + interview"
                        )

                        ProfileMetricTile(
                            title: "Interviews",
                            value: "\(interviewCount)",
                            systemImage: "person.crop.circle.badge.checkmark",
                            tint: Color(red: 0.96, green: 0.73, blue: 0.28),
                            subtitle: interviewRateText
                        )

                        ProfileMetricTile(
                            title: "Companies",
                            value: "\(companyCount)",
                            systemImage: "building.2.fill",
                            tint: Color(red: 0.30, green: 0.80, blue: 0.45),
                            subtitle: "Tracked"
                        )
                    }

                    Text("Tap to open detailed KPI summary, funnel, and top companies.")
                        .font(.footnote)
                        .foregroundStyle(DarkTheme.textSecondary)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .glassCard()
    }

    private func percentageString(_ count: Int, over total: Int) -> String {
        guard total > 0 else { return "0%" }
        let percentage = Double(count) / Double(total)
        return String(format: "%.0f%%", percentage * 100)
    }

    private func updateProfileAvatar(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            profileAvatarDataBase64 = data.base64EncodedString()
        }
    }

    // MARK: - Resume

    private var resumeSection: some View {
        VStack(spacing: 14) {
            HStack {
                SectionLabel(icon: "doc.richtext", title: "Resumes")
                Spacer()
                Button { isShowingDocumentPicker = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(8)
                        .background(Circle().fill(Color.accentColor.opacity(0.12)))
                }
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

                    if resumes.count > 5 {
                        Button { isShowingResumeManager = true } label: {
                            Label("View All", systemImage: "tray.full")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(18)
        .glassCard()
    }

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

    // MARK: - Export

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "square.and.arrow.up", title: "Export Data")

            Button { exportCSV() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(applications.isEmpty ? DarkTheme.textTertiary : Color.accentColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export as CSV")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(applications.isEmpty ? DarkTheme.textSecondary : DarkTheme.textPrimary)

                        Text(applications.isEmpty ? "No applications to export yet." : "Download your applications as a spreadsheet.")
                            .font(.caption)
                            .foregroundStyle(DarkTheme.textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DarkTheme.textTertiary)
                }
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(applications.isEmpty ? Color.primary.opacity(0.05) : Color.accentColor.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(applications.isEmpty ? Color.primary.opacity(0.08) : Color.accentColor.opacity(0.22), lineWidth: 0.8)
                        )
                }
            }
            .disabled(applications.isEmpty)
            .buttonStyle(.plain)

            Text(appVersionFooter)
                .font(.caption2)
                .foregroundStyle(DarkTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(18)
        .glassCard()
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
