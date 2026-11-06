import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Share sheet → "App Nest". Opens App Nest with the shared link or text in the URL
/// (appnest://share?text=…), which drops it straight into Add a Job. No App Group needed, so
/// it signs with any team. If iOS won't open the app, the text goes on the clipboard instead.
final class ShareViewController: UIViewController {
    private let model = ShareStatus()
    private var text = ""

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
        guard let text = await sharedText() else {
            model.state = .failed
            return
        }
        self.text = text
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

    /// Share extensions have no public "open my app" API, and `UIApplication.open` is marked
    /// extension-unavailable. The responder chain still reaches the UIApplication, so call
    /// `open(_:options:completionHandler:)` through the runtime. If iOS ever refuses, the
    /// completion says so: the text goes on the clipboard and the card explains what to do.
    private func openApp() {
        var components = URLComponents()
        components.scheme = "appnest"
        components.host = "share"
        components.queryItems = [URLQueryItem(name: "text", value: String(text.prefix(50_000)))]
        guard let url = components.url else { return openManually() }

        typealias Completion = @convention(block) (Bool) -> Void
        typealias OpenFn = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, Completion?) -> Void
        let selector = NSSelectorFromString("openURL:options:completionHandler:")

        var responder: UIResponder? = self
        while let r = responder {
            if r.isKind(of: UIApplication.self), let imp = r.method(for: selector) {
                let completion: Completion = { [weak self] opened in
                    if opened { self?.finish() } else { self?.openManually() }
                }
                unsafeBitCast(imp, to: OpenFn.self)(r, selector, url as NSURL, [:] as NSDictionary, completion)
                return
            }
            responder = r.next
        }
        openManually()
    }

    private func openManually() {
        UIPasteboard.general.string = text
        model.state = .openManually
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

@MainActor @Observable
final class ShareStatus {
    enum State { case working, openManually, failed }
    var state: State = .working
}

private struct ShareCard: View {
    let status: ShareStatus
    let onDone: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            switch status.state {
            case .working:
                ProgressView()
                Text("Sending to App Nest…").font(.headline)
            case .openManually:
                Image(systemName: "doc.on.clipboard.fill").font(.system(size: 44)).foregroundStyle(.green)
                Text("Copied").font(.headline)
                Text("Open App Nest, tap +, and paste it into Paste Job Link or Parse Email.")
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
