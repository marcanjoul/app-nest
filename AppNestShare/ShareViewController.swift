import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared constants

private let appGroupID       = "group.com.example.mark.appnest"
private let pendingImportKey = "pendingJobImport"
private let logoPublicKey    = "pk_PaR2J13cQXyRshj6wOxhVw"
private let logoSecretKey    = "sk_SFlbaAHcRcWM_u3MDsFnPw"

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
        extractJobInfo { [weak self] pending, rawURL in
            guard let self else { return }
            let model = ShareViewModel(initial: pending, rawURL: rawURL)
            let rootView = ShareView(
                model: model,
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

    private func extractJobInfo(completion: @escaping (SharePendingImport, URL?) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion(SharePendingImport(companyName: "", position: "", sourceURL: nil), nil)
            return
        }

        var foundURL: URL?
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
                        if let url = data as? URL, url.scheme?.hasPrefix("http") == true {
                            foundURL = url
                        } else if let str = data as? String, str.hasPrefix("http"),
                                  let url = URL(string: str) {
                            foundURL = url
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { data, _ in
                        defer { group.leave() }
                        if let str = data as? String {
                            if str.hasPrefix("http"), let url = URL(string: str.components(separatedBy: .whitespacesAndNewlines).first ?? "") {
                                foundURL = foundURL ?? url
                            } else if pageTitle == nil {
                                pageTitle = str
                            }
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) {
            let parsed = Self.parseJobInfo(title: pageTitle, url: foundURL)
            completion(parsed, foundURL)
        }
    }

    // MARK: - Parsing

    static func parseJobInfo(title: String?, url: URL?) -> SharePendingImport {
        var company = ""
        var position = ""

        if let raw = title {
            let noise = [
                " | LinkedIn Jobs", " - LinkedIn Jobs",
                " | LinkedIn",      " - LinkedIn",
                " | Indeed",        " - Indeed",
                " | Glassdoor",     " - Glassdoor",
                " | Handshake",     " - Handshake",
                " | Wellfound",     " - Wellfound",
                " | Lever",         " - Lever",
                " | Greenhouse",    " - Greenhouse",
                " | Workday",       " - Workday",
                " Jobs",            " - Jobs",
            ]
            var cleaned = raw
            for n in noise { cleaned = cleaned.replacingOccurrences(of: n, with: "", options: .caseInsensitive) }
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)

            // "Apply for Position at Company"
            if cleaned.lowercased().hasPrefix("apply for ") {
                cleaned = String(cleaned.dropFirst("apply for ".count)).trimmingCharacters(in: .whitespaces)
            }
            // "Company is hiring a Position" / "Company is hiring Position"
            if let r = cleaned.range(of: " is hiring ", options: .caseInsensitive) {
                company  = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                var pos  = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if pos.lowercased().hasPrefix("a ") || pos.lowercased().hasPrefix("an ") {
                    pos = pos.components(separatedBy: " ").dropFirst().joined(separator: " ")
                }
                position = pos
            }
            // "Position at Company"
            else if let r = cleaned.range(of: " at ", options: .caseInsensitive) {
                position = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                company  = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            // "Company - Position" / "Company – Position"
            else if let r = cleaned.range(of: " - ") ?? cleaned.range(of: " – ") {
                company  = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                position = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            // "Company | Position"
            else if let r = cleaned.range(of: " | ") {
                company  = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
                position = String(cleaned[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }

        return SharePendingImport(
            companyName: company,
            position: position,
            sourceURL: url?.absoluteString
        )
    }

    // MARK: - Save

    private func saveAndDismiss(_ pending: SharePendingImport) {
        if let data = try? JSONEncoder().encode(pending) {
            UserDefaults(suiteName: appGroupID)?.set(data, forKey: pendingImportKey)
        }
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

// MARK: - View model

@Observable
private final class ShareViewModel {
    var companyName: String
    var position: String
    let sourceURL: URL?

    var logoData: Data?
    var isFetchingTitle = false

    init(initial: SharePendingImport, rawURL: URL?) {
        companyName = initial.companyName
        position    = initial.position
        sourceURL   = rawURL

        // If parsing gave empty results and we have a URL, fetch the page title
        if companyName.isEmpty && position.isEmpty, rawURL != nil {
            isFetchingTitle = true
            Task { await fetchPageTitle(from: rawURL) }
        }
    }

    @MainActor
    func fetchPageTitle(from url: URL?) async {
        defer { isFetchingTitle = false }
        guard let url else { return }

        var request = URLRequest(url: url, timeoutInterval: 6)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return }

        // Extract <title>…</title>
        if let start = html.range(of: "<title", options: .caseInsensitive),
           let tagEnd = html[start.lowerBound...].range(of: ">"),
           let titleEnd = html[tagEnd.upperBound...].range(of: "</title>", options: .caseInsensitive) {
            let raw = String(html[tagEnd.upperBound..<titleEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let decoded = raw
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")

            let parsed = ShareViewController.parseJobInfo(title: decoded, url: url)
            if !parsed.companyName.isEmpty || !parsed.position.isEmpty {
                companyName = parsed.companyName
                position    = parsed.position
            }
        }
    }

    @MainActor
    func fetchLogo(for name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let searchURL = URL(string: "https://api.logo.dev/search?q=\(q)") else { return }
        var req = URLRequest(url: searchURL)
        req.setValue("Bearer \(logoSecretKey)", forHTTPHeaderField: "Authorization")

        guard let (sData, _) = try? await URLSession.shared.data(for: req),
              let results = try? JSONDecoder().decode([LogoResult].self, from: sData),
              let domain = results.first?.domain, !domain.isEmpty,
              let imgURL = URL(string: "https://img.logo.dev/\(domain)?token=\(logoPublicKey)&size=128"),
              let (imgData, _) = try? await URLSession.shared.data(from: imgURL),
              !imgData.isEmpty
        else { return }

        logoData = imgData
    }
}

private struct LogoResult: Decodable { let domain: String }

// MARK: - SwiftUI view

private struct ShareView: View {
    @State var model: ShareViewModel
    let onSave: (SharePendingImport) -> Void
    let onCancel: () -> Void

    private var canSave: Bool {
        !model.companyName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.position.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                handle
                header
                Divider().opacity(0.12)
                ScrollView {
                    VStack(spacing: 16) {
                        avatarRow
                        fields
                        if let url = model.sourceURL {
                            urlChip(url.host ?? url.absoluteString)
                        }
                    }
                    .padding(20)
                }
                addButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                    .padding(.top, 6)
            }
        }
        .preferredColorScheme(.dark)
        .task(id: model.companyName) {
            guard !model.companyName.isEmpty else { return }
            await model.fetchLogo(for: model.companyName)
        }
    }

    // MARK: - Subviews

    private var handle: some View {
        Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private var header: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("App Nest")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.primary)
            Spacer()
            Text("Cancel").opacity(0).font(.system(size: 16)) // balance
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var avatarRow: some View {
        HStack(spacing: 14) {
            avatar
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(model.companyName.isEmpty ? "Company" : model.companyName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(model.companyName.isEmpty ? .tertiary : .primary)
                Text(model.position.isEmpty ? "Position" : model.position)
                    .font(.system(size: 14))
                    .foregroundStyle(model.position.isEmpty ? .tertiary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if model.isFetchingTitle {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.secondary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .animation(.easeOut(duration: 0.2), value: model.companyName)
        .animation(.easeOut(duration: 0.2), value: model.position)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = model.logoData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.04))
        } else {
            let initial = model.companyName.prefix(1).uppercased()
            Text(initial.isEmpty ? "?" : initial)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(avatarGradient(for: model.companyName))
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            field("Company", text: Binding(
                get: { model.companyName },
                set: { model.companyName = $0 }
            ), placeholder: "e.g. Google")

            field("Position", text: Binding(
                get: { model.position },
                set: { model.position = $0 }
            ), placeholder: "e.g. Software Engineer")
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.4)
                .textCase(.uppercase)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.7)
                )
        }
    }

    private func urlChip(_ host: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "link")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(host)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.04), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addButton: some View {
        Button {
            onSave(SharePendingImport(
                companyName: model.companyName,
                position: model.position,
                sourceURL: model.sourceURL?.absoluteString
            ))
        } label: {
            Text("Add to App Nest")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canSave ? .white : Color.white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    Capsule()
                        .fill(canSave ? Color.accentColor : Color.white.opacity(0.08))
                        .shadow(color: canSave ? Color.accentColor.opacity(0.35) : .clear, radius: 12, y: 4)
                )
        }
        .disabled(!canSave)
        .animation(.easeOut(duration: 0.16), value: canSave)
    }

    // Deterministic gradient matching the main app's avatarGradient
    private func avatarGradient(for name: String) -> LinearGradient {
        let palettes: [(Color, Color)] = [
            (Color(red: 0.33, green: 0.47, blue: 0.98), Color(red: 0.20, green: 0.60, blue: 0.86)),
            (Color(red: 0.82, green: 0.35, blue: 0.62), Color(red: 0.56, green: 0.20, blue: 0.75)),
            (Color(red: 0.25, green: 0.72, blue: 0.55), Color(red: 0.18, green: 0.52, blue: 0.75)),
            (Color(red: 0.95, green: 0.55, blue: 0.22), Color(red: 0.90, green: 0.30, blue: 0.30)),
            (Color(red: 0.45, green: 0.65, blue: 0.95), Color(red: 0.30, green: 0.45, blue: 0.80)),
        ]
        let idx = abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % palettes.count
        return LinearGradient(colors: [palettes[idx].0, palettes[idx].1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
