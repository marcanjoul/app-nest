import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AddMenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

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
    @State private var showLinkedInError = false

    // Email parse
    @State private var vm = EmailParseViewModel()
    @State private var isShowingEmailParse = false
    @FocusState private var isEmailEditorFocused: Bool
    @State private var cardsVisible = false

    private let linkParser = LinkParser()

    private var defaultResume: ResumeDocument? { resumes.first(where: \.isDefault) }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 16) {
                    pasteLinkCard
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 12)
                        .animation(.appSmooth.delay(0.0), value: cardsVisible)

                    emailParseCard
                        .padding(.horizontal, isShowingEmailParse ? -16 : 0)
                        .animation(.appSmooth, value: isShowingEmailParse)
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 12)
                        .animation(.appSmooth.delay(0.05), value: cardsVisible)

                    actionCard(
                        title: "Import CSV",
                        subtitle: "Bulk upload applications.",
                        icon: "square.and.arrow.down.fill",
                        color: Color.blue
                    ) {
                        AppHaptics.shared.light()
                        isSelectingCSVFile = true
                    }
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 12)
                    .animation(.appSmooth.delay(0.10), value: cardsVisible)

                    actionCard(
                        title: "Add Manually",
                        subtitle: "Enter details from scratch.",
                        icon: "square.and.pencil",
                        color: Color.accentColor
                    ) {
                        AppHaptics.shared.light()
                        isPresentingManualAdd = true
                    }
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 12)
                    .animation(.appSmooth.delay(0.15), value: cardsVisible)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .onAppear { cardsVisible = true }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("Add Job")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: Binding(
            get: { isPresentingManualAdd },
            set: { isPresentingManualAdd = $0; appState.isPresentingSheet = $0 }
        )) {
            NavigationStack { JobDetailView(job: nil) }
        }
        .sheet(isPresented: Binding(
            get: { isPresentingParsedJob },
            set: { isPresentingParsedJob = $0; appState.isPresentingSheet = $0 }
        )) {
            NavigationStack {
                JobDetailView(
                    job: nil,
                    prefillCompany: parsedData?.companyName ?? "",
                    prefillPosition: parsedData?.position ?? "",
                    prefillURL: parsedData?.jobURL ?? ""
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { isPresentingImport },
            set: { isPresentingImport = $0; appState.isPresentingSheet = $0 }
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
            appState.isPresentingSheet = true
        }
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
                AppHaptics.shared.light()
                withAnimation(.appSmooth) {
                    isShowingEmailParse.toggle()
                    if isShowingEmailParse {
                        isEmailEditorFocused = true
                    } else {
                        isEmailEditorFocused = false
                        vm.reset()
                    }
                }
            } label: {
                CardRowHeader(
                    icon: "envelope.open.fill",
                    iconColor: .orange,
                    title: "Parse Email",
                    subtitle: "Extract details from an email."
                ) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                        .rotationEffect(.degrees(isShowingEmailParse ? -180 : 0))
                }
            }
            .buttonStyle(PressScaleButtonStyle())

            if isShowingEmailParse {
                VStack(spacing: 16) {
                    Divider().opacity(0.4)

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
                                            Image(systemName: "pencil")
                                                .font(.system(size: 10, weight: .semibold))
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
                                    .font(.system(size: 13))
                                    .lineLimit(vm.isHighlightExpanded ? nil : 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(Theme.textSecondary)

                                Button {
                                    withAnimation(.appCrisp) { vm.isHighlightExpanded.toggle() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(vm.isHighlightExpanded ? "Show less" : "Show full email")
                                            .font(.caption.weight(.medium))
                                        Image(systemName: vm.isHighlightExpanded ? "chevron.up" : "chevron.down")
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
                                    .frame(height: vm.hasResult ? 90 : 180)
                                    .font(.subheadline)
                                    .focused($isEmailEditorFocused)
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                isEmailEditorFocused ? Color.orange.opacity(0.55) : Color.primary.opacity(0.08),
                                                lineWidth: isEmailEditorFocused ? 1.5 : 1
                                            )
                                    )
                            }
                            .padding(.bottom, 12)

                            Button {
                                withAnimation(.appFastOut) { vm.isButtonPressed = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    withAnimation(.appFastOut) { vm.isButtonPressed = false }
                                }
                                vm.parseEmail(defaultResume: defaultResume)
                            } label: {
                                HStack(spacing: 8) {
                                    if vm.isParsing {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: vm.hasResult ? "arrow.clockwise.circle.fill" : "sparkles")
                                    }
                                    Text(vm.isParsing ? "Parsing…" : vm.hasResult ? "Re-parse" : "Parse Email")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    Capsule()
                                        .fill(vm.isParseDisabled ? Color.secondary.opacity(0.3) : Color.orange)
                                }
                            }
                            .scaleEffect(vm.isButtonPressed ? AppAnimations.pressScale : 1.0)
                            .disabled(vm.isParseDisabled)
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.horizontal, 20)

                    if vm.hasResult {
                        EmailParseResultsCard(
                            vm: vm,
                            resumes: resumes,
                            onSave: {
                                vm.saveApplication(
                                    modelContext: modelContext,
                                    cycles: cycles,
                                    selectedCycleID: appState.selectedCycleID
                                ) {
                                    isShowingEmailParse = false
                                }
                            },
                            onCancel: { vm.reset() }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }

                    if vm.saveSuccess {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button {
                                    vm.reset()
                                    isEmailEditorFocused = true
                                } label: {
                                    Text("Parse New Email")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                }

                                Button {
                                    withAnimation(.appSmooth) {
                                        isShowingEmailParse = false
                                        vm.reset()
                                    }
                                } label: {
                                    Text("Done")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .glassCard(cornerRadius: Theme.cardRadius)
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
                        isTextFieldFocused = true
                    } else {
                        isTextFieldFocused = false
                        pasteLinkURL = ""
                    }
                }
            } label: {
                CardRowHeader(
                    icon: "link",
                    iconColor: .purple,
                    title: "Paste Job Link",
                    subtitle: "Auto-extract company and role."
                ) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                        .rotationEffect(.degrees(isShowingPasteLink ? -180 : 0))
                }
            }
            .buttonStyle(PressScaleButtonStyle())

            if isShowingPasteLink {
                VStack(spacing: 12) {
                    Divider().opacity(0.4)

                    HStack(spacing: 12) {
                        TextField("https://...", text: $pasteLinkURL)
                            .focused($isTextFieldFocused)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isTextFieldFocused ? Color.purple.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .onChange(of: pasteLinkURL) { _, _ in
                                withAnimation(.appFastOut) { showLinkedInError = false }
                            }

                        Button {
                            parseLink()
                        } label: {
                            Group {
                                if isParsing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Parse")
                                }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 44)
                            .background(pasteLinkURL.isEmpty ? Color.secondary.opacity(0.3) : Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .disabled(pasteLinkURL.isEmpty || isParsing)
                        .scaleEffect(isParsing ? 0.95 : 1.0)
                        .animation(.appFastOut, value: pasteLinkURL.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, showLinkedInError ? 12 : 20)
                    .padding(.top, 12)

                    if showLinkedInError {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("LinkedIn Links Not Supported")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("LinkedIn obscures job details in their URLs. Please open the actual application link or add manually.")
                                    .font(.system(size: 12))
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
        .glassCard(cornerRadius: Theme.cardRadius)
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.4))
            }
            .glassCard(cornerRadius: Theme.cardRadius)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Link Parsing

    private func parseLink() {
        guard !pasteLinkURL.isEmpty else { return }
        #if canImport(UIKit)
        UIApplication.shared.dismissKeyboard()
        #endif
        AppHaptics.shared.medium()
        withAnimation(.appFastOut) { isParsing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let result = linkParser.parse(pasteLinkURL)
            withAnimation(.appSmooth) {
                isParsing = false
                if result.isLinkedIn {
                    showLinkedInError = true
                } else {
                    parsedData = result
                    isPresentingParsedJob = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        pasteLinkURL = ""
                        isShowingPasteLink = false
                    }
                }
            }
        }
    }
}
