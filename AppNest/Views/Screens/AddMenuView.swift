import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AddMenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    // Link parsing
    @State private var isShowingPasteLink = false
    @State private var pasteLinkURL = ""
    @State private var isParsing = false
    @State private var parsedData: LinkParser.ParsedResult?
    @FocusState private var isTextFieldFocused: Bool

    // Presentation
    @State private var isPresentingManualAdd = false
    @State private var isPresentingParsedJob = false
    @State private var isSelectingCSVFile = false
    @State private var csvImportRows: [CSVImportRow] = []
    @State private var isPresentingImport = false
    /// Inline warning under the link field: (title, explanation).
    @State private var linkError: (title: String, message: String)?

    // Email parse
    @State private var vm = EmailParseViewModel()
    @State private var isShowingEmailParse = false
    /// Company of the application just added from an email. Non-nil swaps the card body for a
    /// compact confirmation with "Parse New Email" / "Done", instead of collapsing the card.
    @State private var lastSavedCompany: String?
    @State private var lastSavedPosition = ""
    @State private var lastSavedLogo: Data?
    @FocusState private var isEmailEditorFocused: Bool

    private let linkParser = LinkParser()

    private var defaultResume: ResumeDocument? { resumes.first(where: \.isDefault) }
    private let linkAccent = Theme.textPrimary
    private let emailAccent = Theme.textPrimary
    private let importAccent = Theme.textPrimary

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pasteLinkCard

                    emailParseCard
                        .id("emailParseCard")
                        .padding(.horizontal, isShowingEmailParse ? -16 : 0)
                        .animation(.appSmooth, value: isShowingEmailParse)

                    actionCard(
                        title: "Import CSV",
                        subtitle: "Bulk upload applications.",
                        icon: "square.and.arrow.down.fill",
                        color: importAccent
                    ) {
                        isSelectingCSVFile = true
                    }

                    actionCard(
                        title: "Add Manually",
                        subtitle: "Enter details from scratch.",
                        icon: "square.and.pencil",
                        color: Theme.accent
                    ) {
                        isPresentingManualAdd = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            // In the sheet the email card sits below the link card; lift it to the top so the
            // editor *and* its Parse button clear the keyboard.
            .onChange(of: isShowingEmailParse) { _, isOpen in
                guard isOpen else { return }
                withAnimation(.appSmooth) { proxy.scrollTo("emailParseCard", anchor: .top) }
            }
            // The scroll above fires before the keyboard is up, while the content may be too short
            // to scroll. Once the keyboard lands, pin the Parse button just above it.
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                guard isShowingEmailParse, isEmailEditorFocused else { return }
                withAnimation(.appSmooth) { proxy.scrollTo("emailParseCTA", anchor: .bottom) }
            }
            }
        }
        .navigationTitle("Add a Job")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .close) { dismiss() }
            }
        }
        .dismissKeyboardToolbar()
        .sheet(isPresented: Binding(
            get: { isPresentingManualAdd },
            set: { isPresentingManualAdd = $0 }
        )) {
            NavigationStack { JobDetailView(job: nil) }
        }
        .sheet(isPresented: Binding(
            get: { isPresentingParsedJob },
            set: { isPresentingParsedJob = $0 }
        )) {
            NavigationStack {
                JobDetailView(
                    job: nil,
                    prefillCompany: parsedData?.companyName ?? "",
                    prefillPosition: parsedData?.position ?? "",
                    prefillURL: parsedData?.jobURL ?? "",
                    prefillType: parsedData?.jobType,
                    prefillWorkMode: parsedData?.workMode,
                    prefillLocation: parsedData?.location ?? ""
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { isPresentingImport },
            set: { isPresentingImport = $0 }
        )) {
            CSVImportPreviewSheet(initialRows: csvImportRows)
        }
        .fileImporter(
            isPresented: $isSelectingCSVFile,
            allowedContentTypes: [.commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            guard let url = try? result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            csvImportRows = CSVImporter.parse(content)
            isPresentingImport = true
        }
        .task(id: appState.sharedText) { handleSharedText() }
        .task(id: vm.editCompany) {
            await vm.fetchLogo(isDark: colorScheme == .dark)
        }
    }

    // MARK: - Email Parse Card

    @ViewBuilder
    private var emailParseCard: some View {
        let bvm = Bindable(vm)
        VStack(spacing: 0) {
            Button {
                withAnimation(.appSmooth) {
                    isShowingEmailParse.toggle()
                    lastSavedCompany = nil
                    if isShowingEmailParse {
                        isShowingPasteLink = false
                        isTextFieldFocused = false
                        isEmailEditorFocused = true
                    } else {
                        isEmailEditorFocused = false
                        vm.reset()
                    }
                }
            } label: {
                CardRowHeader(
                    icon: "envelope.open.fill",
                    iconColor: emailAccent,
                    title: "Parse Email",
                    subtitle: "Extract details from an email.",
                    isExpanded: isShowingEmailParse
                ) {
                    AppIcon("chevron.down")
                        .appFont(12, weight: .bold)
                        .foregroundStyle(Theme.textSecondary.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                        .rotationEffect(.degrees(isShowingEmailParse ? -180 : 0))
                }
            }
            .buttonStyle(PressScaleButtonStyle())

            if isShowingEmailParse {
                VStack(spacing: 16) {
                    Divider().opacity(0.4)

                    if lastSavedCompany == nil {
                    VStack(alignment: .leading, spacing: 0) {
                        if !vm.isEmailExpanded && !vm.emailText.isEmpty && !vm.highlights.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Spacer()
                                    Button {
                                        vm.backToEdit()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            isEmailEditorFocused = true
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            AppIcon("pencil")
                                                .appFont(10, weight: .semibold)
                                            Text("Edit")
                                                .appFont(.footnote, weight: .semibold)
                                        }
                                        .foregroundStyle(Theme.textSecondary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 5)
                                        .background {
                                            Capsule()
                                                .fill(Color.primary.opacity(0.06))
                                                .overlay {
                                                    Capsule()
                                                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                                                }
                                        }
                                    }
                                    .buttonStyle(PressScaleButtonStyle())
                                }

                                Text(vm.buildHighlightedString(vm.emailText, spans: vm.highlights))
                                    .appFont(.footnote)
                                    .lineLimit(vm.isHighlightExpanded ? nil : 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(Theme.textSecondary)

                                Button {
                                    withAnimation(.appCrisp) { vm.isHighlightExpanded.toggle() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(vm.isHighlightExpanded ? "Show less" : "Show full email")
                                            .appFont(.footnote, weight: .medium)
                                        AppIcon(vm.isHighlightExpanded ? "chevron.up" : "chevron.down")
                                            .appFont(.caption, weight: .semibold)
                                    }
                                    .foregroundStyle(Theme.accent.opacity(0.85))
                                }
                            }
                            .padding(.bottom, 12)
                        }

                        if vm.isEmailExpanded {
                            ZStack(alignment: .topLeading) {
                                if vm.emailText.isEmpty {
                                    Text("Paste your email here…")
                                        .foregroundStyle(.secondary)
                                        .appFont(.body)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                                TextEditor(text: bvm.emailText)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .frame(height: 90)
                                    .appFont(.body)
                                    .focused($isEmailEditorFocused)
                                    // A paste lands as one big jump; typing never adds more than a few
                                    // characters at once. Drop the keyboard so the Parse button shows.
                                    .onChange(of: vm.emailText) { old, new in
                                        if new.count - old.count > 20 { isEmailEditorFocused = false }
                                    }
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .strokeBorder(
                                                isEmailEditorFocused ? emailAccent.opacity(0.55) : Color.primary.opacity(0.08),
                                                lineWidth: isEmailEditorFocused ? 1.5 : 1
                                            )
                                    )
                            }
                            .padding(.bottom, 12)

                            primaryCTA(vm.hasResult ? "Re-parse" : "Parse Email",
                                       icon: vm.hasResult ? "arrow.clockwise" : "sparkles",
                                       isDisabled: vm.isParseDisabled) {
                                vm.parseEmail(defaultResume: defaultResume)
                            }
                            .padding(.bottom, 20)
                            .id("emailParseCTA")
                        }
                    }
                    .padding(.horizontal, 20)

                    if vm.hasResult {
                        EmailParseResultsCard(
                            vm: vm,
                            resumes: resumes,
                            onSave: {
                                let company = vm.editCompany.isEmpty ? "Application" : vm.editCompany
                                // Captured before save — saveApplication resets the view model.
                                lastSavedPosition = vm.editPosition
                                lastSavedLogo = vm.fetchedLogoData
                                vm.saveApplication(
                                    modelContext: modelContext,
                                    cycles: cycles,
                                    selectedCycleID: appState.selectedCycleID
                                ) {
                                    lastSavedCompany = company
                                }
                            },
                            onCancel: { vm.reset() }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    }

                    if let saved = lastSavedCompany {
                        SavedEmailConfirmation(
                            company: saved,
                            position: lastSavedPosition,
                            logoData: lastSavedLogo,
                            onParseNew: {
                                withAnimation(.appSmooth) { lastSavedCompany = nil }
                                isEmailEditorFocused = true
                            },
                            onDone: {
                                withAnimation(.appSmooth) {
                                    isShowingEmailParse = false
                                    lastSavedCompany = nil
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .surface(cornerRadius: Theme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(isShowingEmailParse ? 0.15 : 0.0), lineWidth: 1)
        )
        .animation(.appSmooth, value: isShowingEmailParse)
        .animation(.appSmooth, value: vm.hasResult)
        .animation(.appSmooth, value: vm.isEmailExpanded)
    }

    // MARK: - Paste Link Card

    @ViewBuilder
    private var pasteLinkCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.appSmooth) {
                    isShowingPasteLink.toggle()
                    if isShowingPasteLink {
                        isShowingEmailParse = false
                        isEmailEditorFocused = false
                        isTextFieldFocused = true
                    } else {
                        isTextFieldFocused = false
                        pasteLinkURL = ""
                    }
                }
            } label: {
                CardRowHeader(
                    icon: "link",
                    iconColor: linkAccent,
                    title: "Paste Job Link",
                    subtitle: "Auto-extract company and role.",
                    isExpanded: isShowingPasteLink
                ) {
                    AppIcon("chevron.down")
                        .appFont(12, weight: .bold)
                        .foregroundStyle(Theme.textSecondary.opacity(0.55))
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                        .rotationEffect(.degrees(isShowingPasteLink ? -180 : 0))
                }
            }
            .buttonStyle(PressScaleButtonStyle())

            if isShowingPasteLink {
                VStack(spacing: 12) {
                    Divider().opacity(0.4)

                    VStack(spacing: 12) {
                        TextField("https://...", text: $pasteLinkURL)
                            .focused($isTextFieldFocused)
                            .appFont(.body)
                            .foregroundStyle(Theme.textPrimary)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit(parseLink)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(isTextFieldFocused ? linkAccent.opacity(0.55) : Color.primary.opacity(0.08),
                                                          lineWidth: isTextFieldFocused ? 1.5 : 1)
                                    )
                            }
                            .onChange(of: pasteLinkURL) { _, _ in
                                withAnimation(.appFastOut) { linkError = nil }
                            }

                        if isParsing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        } else {
                            primaryCTA("Parse Link", icon: "sparkles", isDisabled: !isPasteLinkValid, action: parseLink)
                                .animation(.appFastOut, value: isPasteLinkValid)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, linkError != nil ? 12 : 20)
                    .padding(.top, 12)

                    if let linkError {
                        HStack(alignment: .top, spacing: 10) {
                            AppIcon("exclamationmark.triangle.fill")
                                .appFont(14)
                                .foregroundStyle(Color.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(linkError.title)
                                    .appFont(.footnote, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(linkError.message)
                                    .appFont(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .surface(cornerRadius: Theme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(isShowingPasteLink ? 0.15 : 0.0), lineWidth: 1)
        )
        .animation(.appSmooth, value: isShowingPasteLink)
    }

    // MARK: - Action Card

    private func actionCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CardRowHeader(icon: icon, iconColor: color, title: title, subtitle: subtitle) {
                AppIcon("chevron.right")
                    .appFont(12, weight: .bold)
                    .foregroundStyle(Theme.textSecondary.opacity(0.55))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .surface(cornerRadius: Theme.cardRadius)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Primary CTA

    /// Same spec as `JobDetailView.saveBar`: 44pt green glass capsule, 14pt bold label, icon in a 28pt circle.
    private func primaryCTA(_ title: String, icon: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .appFont(.body, weight: .bold)
                Spacer()
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 28, height: 28)
                    AppIcon(icon)
                        .appFont(10, weight: .bold)
                }
            }
            .foregroundStyle(.white)
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .glassEffect(.regular.tint(isDisabled ? Color.secondary.opacity(0.3) : Theme.buttonGreen).interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    // MARK: - Shared Item

    /// A share from Safari/Mail: links go straight into Parse Link, anything else is parsed as an email.
    private func handleSharedText() {
        guard let text = appState.sharedText else { return }
        appState.sharedText = nil
        withAnimation(.appSmooth) {
            lastSavedCompany = nil
            if LinkParser.webURL(from: text) != nil {
                isShowingEmailParse = false
                pasteLinkURL = text.trimmingCharacters(in: .whitespacesAndNewlines)
                isShowingPasteLink = true
            } else {
                isShowingPasteLink = false
                vm.reset()
                vm.emailText = text
                isShowingEmailParse = true
            }
        }
        if isShowingPasteLink { parseLink() } else { vm.parseEmail(defaultResume: defaultResume) }
    }

    // MARK: - Link Parsing

    private var isPasteLinkValid: Bool { LinkParser.webURL(from: pasteLinkURL) != nil }

    private func parseLink() {
        guard isPasteLinkValid else { return }
        #if canImport(UIKit)
        UIApplication.shared.dismissKeyboard()
        #endif
        withAnimation(.appFastOut) { isParsing = true }
        let url = pasteLinkURL
        Task {
            let result = await linkParser.parse(url)
            await MainActor.run {
                withAnimation(.appSmooth) {
                    isParsing = false
                    if result.isLinkedIn {
                        linkError = ("LinkedIn Links Not Supported",
                                     "LinkedIn obscures job details in their URLs. Please open the actual application link or add manually.")
                    } else if result.isNotJobLink {
                        AppHaptics.shared.warning()
                        linkError = ("Not a Job Link",
                                     "This doesn't look like a job posting. Paste the link to the job or application page.")
                    } else {
                        parsedData = result
                        isPresentingParsedJob = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            pasteLinkURL = ""
                            isShowingPasteLink = false
                        }
                    }
                }
            }
        }
    }
}

/// Reusable header row used by expandable and action cards.
/// Renders a tinted icon circle, title, subtitle, and an arbitrary trailing view.
struct CardRowHeader<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    /// Open cards drop the description — the content below explains itself — and the title grows.
    var isExpanded: Bool = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 56, height: 56)
                AppIcon(icon)
                    .appFont(24, weight: .semibold)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(isExpanded ? .title : .headline, weight: isExpanded ? .bold : .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if !isExpanded {
                    Text(subtitle)
                        .appFont(.footnote, weight: .medium)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .animation(.appSmooth, value: isExpanded)

            Spacer()

            trailing()
        }
        .padding(20)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Saved Confirmation

/// Shown in place of the email card's body after a save: the company's logo pops in with a
/// green check, then "Parse New Email" / "Done".
private struct SavedEmailConfirmation: View {
    let company: String
    let position: String
    let logoData: Data?
    let onParseNew: () -> Void
    let onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 12) {
                ZStack {
                    if let logoData, let ui = UIImage(data: logoData) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        InitialAvatar(name: company, fontSize: 28)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .overlay(alignment: .bottomTrailing) {
                    AppIcon("checkmark")
                        .appFont(12, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.buttonGreen))
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2.5))
                        .offset(x: 6, y: 6)
                        .scaleEffect(appeared ? 1 : 0.2)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.55).delay(0.18), value: appeared)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .animation(.spring(response: 0.45, dampingFraction: 0.65), value: appeared)

                VStack(spacing: 4) {
                    Text("Added to Applications")
                        .appFont(.body, weight: .bold)
                        .foregroundStyle(Theme.textPrimary)
                    Text(position.isEmpty ? company : "\(position) · \(company)")
                        .appFont(.footnote, weight: .medium)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(.appSmooth.delay(0.1), value: appeared)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .accessibilityElement(children: .combine)

            HStack(spacing: 12) {
                Button(action: onParseNew) {
                    Text("Parse New Email")
                        .appFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)

                Button(action: onDone) {
                    Text("Done")
                        .appFont(.body, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .glassEffect(.regular.tint(Theme.buttonGreen).interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.appSmooth.delay(0.2), value: appeared)
        }
        .onAppear { appeared = true }
    }
}
