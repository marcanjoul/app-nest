import SwiftUI

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Import Filter

enum ImportPreviewFilter: String, CaseIterable {
    case all = "All"
    case ready = "Ready"
    case attention = "Needs Attention"
}
