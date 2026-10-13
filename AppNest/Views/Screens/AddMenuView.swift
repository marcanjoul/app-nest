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
                    addHeader
                        .padding(.bottom, 2)

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
                        AppHaptics.shared.light()
                        isSelectingCSVFile = true
                    }

                    actionCard(
                        title: "Add Manually",
                        subtitle: "Enter details from scratch.",
                        icon: "square.and.pencil",
                        color: Color.accentColor
                    ) {
                        AppHaptics.shared.light()
                        isPresentingManualAdd = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            // In the sheet the email card sits below the link card; lift it to the top so the
            // editor *and* its Parse button clear the keyboard.
            .onChange(of: isShowingEmailParse) { _, isOpen in
                guard isOpen else { return }
                withAnimation(.appSmooth) { proxy.scrollTo("emailParseCard", anchor: .top) }
            }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
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
                    prefillType: parsedData?.jobType
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
        .task(id: vm.editCompany) {
            await vm.fetchLogo(isDark: colorScheme == .dark)
        }
    }

    private var addHeader: some View {
        HStack(alignment: .center) {
            Text("Add a Job")
                .appFont(34, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Same 44pt glass circle as JobDetailView's close button.
            Button { dismiss() } label: {
                AppIcon("xmark")
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Email Parse Card

    @ViewBuilder
    private var emailParseCard: some View {
        let bvm = Bindable(vm)
        VStack(spacing: 0) {
            Button {
                AppHaptics.shared.light()
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
                    isProminent: true,
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
                                                .font(.caption.weight(.semibold))
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
                                    .appFont(13)
                                    .lineLimit(vm.isHighlightExpanded ? nil : 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(Theme.textSecondary)

                                Button {
                                    withAnimation(.appCrisp) { vm.isHighlightExpanded.toggle() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(vm.isHighlightExpanded ? "Show less" : "Show full email")
                                            .font(.caption.weight(.medium))
                                        AppIcon(vm.isHighlightExpanded ? "chevron.up" : "chevron.down")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .foregroundStyle(Color.accentColor.opacity(0.85))
                                }
                            }
                            .padding(.bottom, 12)
                        }

                        if vm.isEmailExpanded {
                            ZStack(alignment: .topLeading) {
                                if vm.emailText.isEmpty {
                                    Text("Paste your email here…")
                                        .foregroundStyle(.secondary)
                                        .font(.subheadline)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                                TextEditor(text: bvm.emailText)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .frame(height: 90)
                                    .font(.subheadline)
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
                        }
                    }
                    .padding(.horizontal, 20)

                    if vm.hasResult {
                        EmailParseResultsCard(
                            vm: vm,
                            resumes: resumes,
                            onSave: {
                                let company = vm.editCompany.isEmpty ? "Application" : vm.editCompany
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
                        savedConfirmation(company: saved)
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
                AppHaptics.shared.light()
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
                    isProminent: true,
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
                            .appFont(15)
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
                                    .appFont(13, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(linkError.message)
                                    .appFont(12)
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

    // MARK: - Saved Confirmation

    private func savedConfirmation(company: String) -> some View {
        VStack(spacing: 16) {
            AppLabel("Added \(company)", systemImage: "checkmark.circle.fill")
                .appFont(15, weight: .semibold)
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.appSmooth) { lastSavedCompany = nil }
                    isEmailEditorFocused = true
                } label: {
                    Text("Parse New Email")
                        .appFont(14, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.appSmooth) {
                        isShowingEmailParse = false
                        lastSavedCompany = nil
                    }
                } label: {
                    Text("Done")
                        .appFont(14, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .glassEffect(.regular.tint(Theme.buttonGreen).interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Primary CTA

    /// Same spec as `JobDetailView.saveBar`: 44pt green glass capsule, 14pt bold label, icon in a 28pt circle.
    private func primaryCTA(_ title: String, icon: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .appFont(14, weight: .bold)
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

    // MARK: - Link Parsing

    private var isPasteLinkValid: Bool { LinkParser.webURL(from: pasteLinkURL) != nil }

    private func parseLink() {
        guard isPasteLinkValid else { return }
        #if canImport(UIKit)
        UIApplication.shared.dismissKeyboard()
        #endif
        AppHaptics.shared.medium()
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
    var isProminent: Bool = false
    /// Open cards drop the description — the content below explains itself — and the title grows.
    var isExpanded: Bool = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(isProminent ? 0.18 : 0.15))
                    .frame(width: isProminent ? 56 : 48, height: isProminent ? 56 : 48)
                AppIcon(icon)
                    .appFont(isProminent ? 24 : 20, weight: .semibold)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(isExpanded ? 22 : (isProminent ? 18 : 17), weight: isExpanded ? .bold : .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if !isExpanded {
                    Text(subtitle)
                        .appFont(13, weight: .medium)
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
