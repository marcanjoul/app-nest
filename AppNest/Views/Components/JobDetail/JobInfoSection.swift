import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct JobInfoSection: View {
    @Binding var companyName: String
    @Binding var companyLogoImageData: Data?
    @Binding var logoRemoved: Bool
    @Binding var position: String
    @Binding var pickerItem: PhotosPickerItem?
    /// The link didn't give a job title: say so in the field and focus it.
    var promptsForPosition = false
    var onAutoFetchStateChanged: ((Bool) -> Void)? = nil

    private enum Field: Hashable { case company, position }
    private static let logoShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    @FocusState private var focused: Field?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isFetchingLogo = false
    @State private var isLogoAutoFetched = false

    // Company suggestions
    @Query private var applications: [JobApplication]
    @State private var remoteSuggestions: [LogoFetcher.Company] = []
    /// The suggestion last tapped; its logo skips the debounce and the search while the name still matches.
    @State private var picked: Suggestion?

    private struct Suggestion: Identifiable, Equatable {
        let name: String
        var domain: String? = nil
        var logoData: Data? = nil
        /// From the user's own applications rather than the Logo.dev search.
        var isExisting = false
        var id: String { name.lowercased() }
    }

    /// The user's own companies first (same spelling as last time), then Logo.dev matches. Max 5.
    private var suggestions: [Suggestion] {
        let query = companyName.trimmingCharacters(in: .whitespaces)
        guard focused == .company, !query.isEmpty, picked?.name != query else { return [] }
        let lowerQuery = query.lowercased()

        var seen = Set<String>()
        // ponytail: scans every application on each keystroke; fine for hundreds, index if it ever lags.
        let existing = applications
            .compactMap { app -> Suggestion? in
                let name = app.companyName.trimmingCharacters(in: .whitespaces)
                guard name.localizedCaseInsensitiveContains(query),
                      seen.insert(name.lowercased()).inserted else { return nil }
                return Suggestion(name: name, logoData: app.companyLogoImageData, isExisting: true)
            }
            .sorted { $0.name.lowercased().hasPrefix(lowerQuery) && !$1.name.lowercased().hasPrefix(lowerQuery) }
        let remote = remoteSuggestions
            .filter { seen.insert($0.name.lowercased()).inserted }
            .map { Suggestion(name: $0.name, domain: $0.domain) }

        let all = Array((existing + remote).prefix(5))
        // Already typed in full — nothing left to suggest.
        if all.count == 1, all[0].name.lowercased() == lowerQuery { return [] }
        return all
    }

    private var logoImage: Image? {
        guard let data = companyLogoImageData, let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }

    private var hasLogo: Bool {
        guard let data = companyLogoImageData else { return false }
        return UIImage(data: data) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    // Same pastel placeholder as the job card and profile — shown until a logo loads.
                    InitialAvatar(name: companyName, fontSize: 30)
                    .opacity(hasLogo ? 0 : 1)
                    .animation(.appFastOut, value: hasLogo)

                    if let image = logoImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .frame(width: 72, height: 72)
                // Same rounded square as the job card's 60pt / r20 avatar, scaled to 72pt.
                .clipShape(Self.logoShape)
                .background {
                    if isFetchingLogo {
                        Self.logoShape
                            .fill(Color.primary.opacity(0.12))
                    }
                }
                .overlay(
                    Self.logoShape
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.20), radius: 8, y: 4)
                .opacity(isFetchingLogo ? 0.8 : 1.0)
                .animation(.appFastOut, value: isFetchingLogo)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(Theme.background)
                            .frame(width: 22, height: 22)
                        AppIcon("camera.fill")
                            .appFont(9, weight: .bold)
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Theme.buttonGreen))
                    }
                    .offset(x: 2, y: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if hasLogo {
                    LogoRemoveBadge(action: removeLogo)
                        .offset(x: 10, y: -10)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .animation(.appFastOut, value: hasLogo)
            .onChange(of: pickerItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        withAnimation(.appSmooth) {
                            companyLogoImageData = data
                            isLogoAutoFetched = false
                            logoRemoved = false
                        }
                        onAutoFetchStateChanged?(false)
                        AppHaptics.shared.success()
                    }
                }
            }
            .contextMenu {
                if hasLogo {
                    Button(role: .destructive, action: removeLogo) {
                        AppLabel("Remove Logo", systemImage: "trash")
                    }
                }
            }
            .onChange(of: companyName) { _, _ in logoRemoved = false }
            .task(id: companyName) {
                if isLogoAutoFetched {
                    withAnimation(.appFastOut) {
                        companyLogoImageData = nil
                        isLogoAutoFetched = false
                    }
                    onAutoFetchStateChanged?(false)
                }
                guard !logoRemoved, companyLogoImageData == nil else { return }
                let trimmed = companyName.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else { isFetchingLogo = false; return }
                let pick = picked?.name == trimmed ? picked : nil
                if pick == nil {
                    do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                withAnimation(.appFastOut) { isFetchingLogo = true }
                let fetched: Data?
                if let logo = pick?.logoData {
                    fetched = logo
                } else if let domain = pick?.domain {
                    fetched = await LogoFetcher.fetchLogoData(domain: domain, company: trimmed)
                } else {
                    fetched = await LogoFetcher.fetchLogoData(for: trimmed, darkMode: colorScheme == .dark)
                }
                if let data = fetched {
                    withAnimation(.appSmooth) {
                        companyLogoImageData = data
                        isLogoAutoFetched = true
                    }
                    onAutoFetchStateChanged?(true)
                }
                withAnimation(.appFastOut) { isFetchingLogo = false }
            }
            // Type-ahead search. Shorter debounce than the logo fetch above, which then hits
            // LogoFetcher's search cache instead of making its own request.
            .task(id: focused == .company ? companyName : "") {
                let query = companyName.trimmingCharacters(in: .whitespaces)
                guard focused == .company, query.count >= 2 else { remoteSuggestions = []; return }
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                let results = await LogoFetcher.searchCompanies(query) ?? []
                guard !Task.isCancelled else { return }
                withAnimation(.appFastOut) { remoteSuggestions = results }
            }

            VStack(spacing: 12) {
                boxedField(.company, label: "Company", icon: "building.2", placeholder: "Company name",
                           text: $companyName, style: .headline, capitalization: .words, submit: .next) {
                    focused = .position
                }
                if !suggestions.isEmpty {
                    suggestionList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                boxedField(.position, label: "Position", icon: "briefcase",
                           placeholder: promptsForPosition ? "Couldn't find the title, add it here" : "Job title",
                           text: $position, style: .headline, capitalization: .words, submit: .done) {
                    focused = nil
                }
            }
            .padding(.top, 16)
            .animation(.appFastOut, value: suggestions)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .task {
            guard promptsForPosition, position.isEmpty else { return }
            // Wait out the sheet's presentation; focusing mid-animation drops the keyboard.
            try? await Task.sleep(for: .milliseconds(500))
            focused = .position
        }
    }

    private func removeLogo() {
        AppHaptics.shared.light()
        withAnimation(.appFastOut) {
            companyLogoImageData = nil
            isLogoAutoFetched = false
            logoRemoved = true
        }
        onAutoFetchStateChanged?(false)
    }

    // MARK: - Suggestions

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                if index > 0 { Divider().opacity(0.4).padding(.leading, 52) }
                Button { pick(suggestion) } label: {
                    HStack(spacing: 12) {
                        suggestionLogo(suggestion)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(suggestion.name)
                            .appFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(suggestion.isExisting ? "Added before" : (suggestion.domain ?? ""))
                            .appFont(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func suggestionLogo(_ suggestion: Suggestion) -> some View {
        if let data = suggestion.logoData, let ui = UIImage(data: data) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let domain = suggestion.domain, let url = LogoFetcher.logoURL(domain: domain, size: 64) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                InitialAvatar(name: suggestion.name, fontSize: 12)
            }
        } else {
            InitialAvatar(name: suggestion.name, fontSize: 12)
        }
    }

    private func pick(_ suggestion: Suggestion) {
        AppHaptics.shared.selection()
        picked = suggestion
        companyName = suggestion.name
        focused = .position
    }

    // MARK: - Boxed field

    /// Labelled box, same look as the parse card's `EditableFieldRow`. While editing, a long
    /// value scrolls so the cursor end stays visible (the front is cut off). Once focus leaves,
    /// the value shows from the start with "…" at the end instead.
    // ponytail: the truncated label is a Text laid over a transparent TextField — TextField
    // can't tail-truncate on its own. Hit-testing passes through, so tapping still edits.
    @ViewBuilder
    private func boxedField(_ field: Field, label: String, icon: String, placeholder: String,
                            text: Binding<String>, style: AppTextStyle,
                            capitalization: TextInputAutocapitalization, submit: SubmitLabel,
                            onSubmit: @escaping () -> Void) -> some View {
        let isFocused = focused == field
        let isEmpty = text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
        VStack(alignment: .leading, spacing: 6) {
            // Label sits above the box, not inside it.
            HStack(spacing: 6) {
                AppIcon(icon)
                    .appFont(11, weight: .semibold)
                    .frame(width: 14)
                Text(label)
                    .appFont(.footnote, weight: .medium)
                Text("*")
                    .appFont(.footnote, weight: .bold)
                    .foregroundStyle(.orange)
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.leading, 4)

            TextField(placeholder, text: text)
                .appFont(style, weight: .semibold)
                .foregroundStyle(isFocused || isEmpty ? Theme.textPrimary : .clear)
                .textInputAutocapitalization(capitalization)
                .lineLimit(1)
                .focused($focused, equals: field)
                .submitLabel(submit)
                .onSubmit(onSubmit)
                .overlay(alignment: .leading) {
                    if !isFocused && !isEmpty {
                        Text(text.wrappedValue)
                            .appFont(style, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isFocused ? Theme.accent.opacity(0.04) : Color.primary.opacity(0.04))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isFocused ? Theme.accent.opacity(0.5) : Color.primary.opacity(0.07),
                                              lineWidth: isFocused ? 1.5 : 1)
                        }
                }
                .contentShape(Rectangle())
                .onTapGesture { focused = field }
        }
        .animation(.appFastOut, value: isFocused)
    }
}

/// Small red ✕ on a logo's top-right corner; same ring-and-dot build as the camera badge.
struct LogoRemoveBadge: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.background)
                    .frame(width: 22, height: 22)
                AppIcon("xmark")
                    .appFont(8, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Theme.destructive))
            }
            // 22pt is too small to hit reliably; pad the tap area, not the drawing.
            .padding(8)
            .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Remove logo")
    }
}
