import SwiftUI
import QuickLook

/// Shared data structure for full-screen resume viewing.
struct FullscreenResume: Identifiable {
    let id: UUID
    let bookmark: Data
    let fileName: String
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
