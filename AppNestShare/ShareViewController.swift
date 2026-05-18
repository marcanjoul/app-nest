import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared constants

private let appGroupID      = "group.com.example.mark.appnest"
private let pendingImportKey = "pendingJobImport"

// MARK: - Pending import model (mirrors AppNest/Models/PendingJobImport.swift)

struct SharePendingImport: Codable {
    var companyName: String
    var position: String
    var sourceURL: String?
}

// MARK: - View controller

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        extractJobInfo { [weak self] pending in
            guard let self else { return }
            let rootView = ShareView(
                pending: pending,
                onSave: { [weak self] saved in self?.saveAndDismiss(saved) },
                onCancel: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            )
            let host = UIHostingController(rootView: rootView)
            host.view.backgroundColor = .clear
            addChild(host)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            host.didMove(toParent: self)
        }
    }

    // MARK: - Extraction

    private func extractJobInfo(completion: @escaping (SharePendingImport) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(SharePendingImport(companyName: "", position: "", sourceURL: nil))
            return
        }

        var urlString: String?
        var pageTitle: String?

        let group = DispatchGroup()

        for item in items {
            if pageTitle == nil {
                pageTitle = item.attributedTitle?.string ?? item.attributedContentText?.string
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier) { data, _ in
                        defer { group.leave() }
                        if let url = data as? URL { urlString = url.absoluteString }
                        else if let str = data as? String, str.hasPrefix("http") { urlString = str }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                        defer { group.leave() }
                        if let str = data as? String {
                            if str.hasPrefix("http") { urlString = str }
                            else if pageTitle == nil { pageTitle = str }
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) {
            completion(Self.parseJobInfo(title: pageTitle, urlString: urlString))
        }
    }

    // MARK: - Parsing

    private static func parseJobInfo(title: String?, urlString: String?) -> SharePendingImport {
        var company = ""
        var position = ""

        if let raw = title {
            let cleaned = raw
                .replacingOccurrences(of: " | LinkedIn", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " - LinkedIn", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " | Indeed", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " - Indeed", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " | Glassdoor", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " - Glassdoor", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " | Handshake", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: " - Jobs", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)

            // "Software Engineer at Google"
            if let r = cleaned.range(of: " at ", options: .caseInsensitive) {
                position = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                company  = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            // "Google - Software Engineer" or "Google – Position"
            else if let r = cleaned.range(of: " - ") ?? cleaned.range(of: " – ") {
                company  = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                position = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            // "Google | Software Engineer"
            else if let r = cleaned.range(of: " | ") {
                company  = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                position = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        return SharePendingImport(companyName: company, position: position, sourceURL: urlString)
    }

    // MARK: - Save

    private func saveAndDismiss(_ pending: SharePendingImport) {
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults(suiteName: appGroupID)?.set(data, forKey: pendingImportKey)
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

// MARK: - SwiftUI view

private struct ShareView: View {
    @State private var companyName: String
    @State private var position: String
    let sourceURL: String?
    let onSave: (SharePendingImport) -> Void
    let onCancel: () -> Void

    init(pending: SharePendingImport, onSave: @escaping (SharePendingImport) -> Void, onCancel: @escaping () -> Void) {
        _companyName = State(initialValue: pending.companyName)
        _position    = State(initialValue: pending.position)
        sourceURL    = pending.sourceURL
        self.onSave  = onSave
        self.onCancel = onCancel
    }

    private var canSave: Bool {
        !companyName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !position.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.11).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.15)
                ScrollView {
                    VStack(spacing: 14) {
                        if let url = sourceURL { urlPreview(url) }
                        field("Company", text: $companyName, placeholder: "e.g. Google")
                        field("Position", text: $position, placeholder: "e.g. Software Engineer")
                    }
                    .padding(18)
                }
                addButton
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("App Nest")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.primary)
            Spacer()
            // Balance layout
            Text("Cancel").font(.system(size: 16)).opacity(0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func urlPreview(_ url: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(url)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.3)
                .textCase(.uppercase)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
        }
    }

    private var addButton: some View {
        Button {
            onSave(SharePendingImport(companyName: companyName, position: position, sourceURL: sourceURL))
        } label: {
            Text("Add to App Nest")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canSave ? .white : Color.white.opacity(0.35))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Capsule()
                        .fill(canSave ? Color.accentColor : Color.white.opacity(0.1))
                        .shadow(color: canSave ? Color.accentColor.opacity(0.3) : .clear, radius: 10, y: 3)
                )
        }
        .disabled(!canSave)
        .animation(.easeOut(duration: 0.18), value: canSave)
    }
}
