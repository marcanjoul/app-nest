import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

/// Resume picker row used in `JobDetailView`. Shows inline resume pills,
/// a "View All" button, and replace/clear actions for the attached resume.
struct ResumeSection: View {
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

/// Sheet listing the user's saved resumes for selection.
struct ResumeLibrarySheet: View {
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

/// `UIDocumentPickerViewController` wrapper used to pick a resume file.
struct DocumentPicker: UIViewControllerRepresentable {
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
