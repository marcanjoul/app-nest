import SwiftUI
import UniformTypeIdentifiers
import QuickLook
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

    @State private var fullscreenResume: FullscreenResume?

    struct FullscreenResume: Identifiable {
        let id: UUID
        let bookmark: Data
        let fileName: String
    }

    private func openFullscreen(_ resume: ResumeDocument) {
        fullscreenResume = FullscreenResume(id: resume.id, bookmark: resume.bookmark, fileName: resume.fileName)
    }

    @ViewBuilder
    private var primaryPill: some View {
        if let attached = attachedResume {
            ResumePill(
                title: attached.fileName,
                style: .attached,
                isSelected: true,
                isDefault: attached.isDefault,
                isLarge: true,
                action: { openFullscreen(attached) }
            )
            .contextMenu {
                Button {
                    openFullscreen(attached)
                } label: {
                    Label("Open Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Button(action: onViewAll) {
                    Label("Select Another", systemImage: "tray.full")
                }
                Divider()
                Button(role: .destructive, action: onClear) {
                    Label("Remove from Job", systemImage: "trash")
                }
            } preview: {
                ResumePreview(bookmark: attached.bookmark, fileName: attached.fileName)
                    .onTapGesture { openFullscreen(attached) }
            }
        } else if let legacyResumeFileName {
            ResumePill(
                title: legacyResumeFileName,
                style: .attached,
                isSelected: true,
                isLarge: true
            )
        } else if attachedResumeWasDeleted {
            ResumePill(title: "File Deleted", style: .deleted, isLarge: true)
        } else {
            // New premium Add state matching ProfileView
            ResumePill(title: "Attach Resume", style: .add, isLarge: true) {
                onPick()
            }
        }
    }

    private var isShowingUploadOnly: Bool {
        resumes.isEmpty &&
        attachedResume == nil &&
        legacyResumeFileName == nil &&
        !attachedResumeWasDeleted
    }

    private var hasAttachedResume: Bool {
        attachedResume != nil || legacyResumeFileName != nil || attachedResumeWasDeleted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "doc.richtext", title: "Resume")

            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    primaryPill
                    Spacer()
                }
                .padding(.vertical, 4)

                if !isShowingUploadOnly {
                    if resumes.count > 1 {
                        Button(action: onViewAll) {
                            Label("Select Another", systemImage: "tray.full")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.10))
                                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.20), lineWidth: 1))
                                )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }

                    HStack(spacing: 8) {
                        Spacer()
                        Button(action: onPick) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color.accentColor.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add resume")

                        Button(role: .destructive, action: onClear) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(hasAttachedResume ? Color(red: 0.93, green: 0.33, blue: 0.40) : Color(red: 0.93, green: 0.33, blue: 0.40).opacity(0.35))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(Color(red: 0.93, green: 0.33, blue: 0.40).opacity(hasAttachedResume ? 0.10 : 0.04)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasAttachedResume)
                        .accessibilityLabel("Remove attached resume")
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
        .fullScreenCover(item: $fullscreenResume) { resume in
            FullscreenResumeViewer(bookmark: resume.bookmark, fileName: resume.fileName)
        }
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
                                        .foregroundStyle(resume.isDefault ? Color(red: 0.96, green: 0.73, blue: 0.28) : Theme.textSecondary)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.primary.opacity(0.06)))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(resume.fileName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Theme.textPrimary)
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

/// Quick Look preview shown when a resume pill is haptic-touched. Resolves
/// the security-scoped bookmark and renders the file via `QLPreviewController`
/// with a titled header bar on top.
struct ResumePreview: View {
    let bookmark: Data
    let fileName: String

    @State private var resolvedURL: URL?
    @State private var didStartAccessing = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Group {
                if let resolvedURL {
                    QuickLookPreview(url: resolvedURL)
                } else {
                    placeholder
                }
            }
        }
        .frame(width: 320, height: 460)
        .background(Color(UIColor.systemBackground))
        .onAppear { resolve() }
        .onDisappear {
            if didStartAccessing {
                resolvedURL?.stopAccessingSecurityScopedResource()
                didStartAccessing = false
            }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(fileName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Unable to load preview")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.04))
    }

    private func resolve() {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            didStartAccessing = url.startAccessingSecurityScopedResource()
            resolvedURL = url
        }
    }
}

/// Full-screen QuickLook viewer presented when the user taps a resume preview
/// or chooses "Open Full Screen" from the context menu. Includes a Done button.
struct FullscreenResumeViewer: View {
    let bookmark: Data
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var resolvedURL: URL?
    @State private var didStartAccessing = false

    var body: some View {
        NavigationStack {
            Group {
                if let resolvedURL {
                    QuickLookPreview(url: resolvedURL)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Unable to load this resume")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { resolve() }
        .onDisappear {
            if didStartAccessing {
                resolvedURL?.stopAccessingSecurityScopedResource()
                didStartAccessing = false
            }
        }
    }

    private func resolve() {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            didStartAccessing = url.startAccessingSecurityScopedResource()
            resolvedURL = url
        }
    }
}

/// SwiftUI wrapper around `QLPreviewController` for inline document previews.
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
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
