import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Share sheet → "App Nest". Saves the shared link or text to the App Group inbox, then opens
/// App Nest, which picks it up (ShareInbox) and starts parsing. If iOS won't let us open the app,
/// the item is already saved and appears the next time App Nest comes to the foreground.
final class ShareViewController: UIViewController {
    // Must match ShareInbox in the app target.
    private static let appGroup = "group.com.example.mark.AppNest"
    private static let openURL = URL(string: "appnest://share")!

    private let model = ShareStatus()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareCard(status: model, onDone: { [weak self] in self?.finish() },
                                                           onOpen: { [weak self] in self?.openApp() }))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { await handleShare() }
    }

    private func handleShare() async {
        guard let text = await sharedText(), save(text) else {
            model.state = .failed
            return
        }
        model.state = .saved
        openApp()
    }

    /// Prefers a URL (Safari, job boards), falls back to plain text (selected email text).
    private func sharedText() async -> String? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await p.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL, !url.isFileURL {
                return url.absoluteString
            }
        }
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = try? await p.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        return nil
    }

    /// One file per share, so two quick shares can't overwrite each other.
    private func save(_ text: String) -> Bool {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)?
            .appendingPathComponent("ShareInbox", isDirectory: true) else { return false }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try text.write(to: dir.appendingPathComponent("\(Date().timeIntervalSince1970)-\(UUID().uuidString).txt"),
                           atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// Share extensions have no public "open my app" API, and `UIApplication.open` is marked
    /// extension-unavailable. The responder chain still reaches the UIApplication, so call
    /// `open(_:options:completionHandler:)` through the runtime. If iOS ever refuses, the
    /// completion says so and the card stays up with an "Open App Nest" fallback.
    private func openApp() {
        typealias Completion = @convention(block) (Bool) -> Void
        typealias OpenFn = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, Completion?) -> Void
        let selector = NSSelectorFromString("openURL:options:completionHandler:")

        var responder: UIResponder? = self
        while let r = responder {
            if r.isKind(of: UIApplication.self), let imp = r.method(for: selector) {
                let completion: Completion = { [weak self] opened in
                    if opened { self?.finish() } else { self?.model.state = .savedOpenManually }
                }
                unsafeBitCast(imp, to: OpenFn.self)(r, selector, Self.openURL as NSURL, [:] as NSDictionary, completion)
                return
            }
            responder = r.next
        }
        model.state = .savedOpenManually
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

@MainActor @Observable
final class ShareStatus {
    enum State { case working, saved, savedOpenManually, failed }
    var state: State = .working
}

private struct ShareCard: View {
    let status: ShareStatus
    let onDone: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            switch status.state {
            case .working, .saved:
                ProgressView()
                Text("Sending to App Nest…").font(.headline)
            case .savedOpenManually:
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
                Text("Saved to App Nest").font(.headline)
                Text("Open App Nest and it'll be ready to add.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Open App Nest", action: onOpen).buttonStyle(.borderedProminent).tint(.green)
                Button("Done", action: onDone)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
                Text("Nothing to add").font(.headline)
                Text("Share a job link, or select the email's text and share that.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Done", action: onDone)
            }
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.25))
        .animation(.smooth, value: status.state)
    }
}
