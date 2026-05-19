import SwiftUI
import SwiftData

struct EmailParserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    @State private var vm = EmailParseViewModel()
    @State private var cardAppeared = false
    @State private var scrollToResults = false
    @FocusState private var isEditorFocused: Bool

    private var defaultResume: ResumeDocument? { resumes.first(where: \.isDefault) }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        inputCard
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
                                        dismiss()
                                    }
                                },
                                onCancel: { vm.reset() }
                            )
                            .id("results")
                        }
                    }
                    .padding()
                    .animation(.appSmooth, value: vm.hasResult)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: scrollToResults) { _, newValue in
                    guard newValue else { return }
                    scrollToResults = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.appSmooth) {
                            proxy.scrollTo("results", anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationTitle("Parse Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    #if canImport(UIKit)
                    UIApplication.shared.dismissKeyboard()
                    #endif
                }
            }
        }
        .onAppear {
            withAnimation(.appSmooth.delay(0.1)) { cardAppeared = true }
        }
        .task(id: vm.editCompany) {
            vm.fetchedLogoData = nil
            vm.isFetchingLogo = false
            let trimmed = vm.editCompany.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
            do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.appFastOut) { vm.isFetchingLogo = true }
            vm.fetchedLogoData = await LogoFetcher.fetchLogoData(for: trimmed, darkMode: colorScheme == .dark)
            withAnimation(.appFastOut) { vm.isFetchingLogo = false }
        }
    }

    // MARK: - Input Card

    @ViewBuilder
    private var inputCard: some View {
        let bvm = Bindable(vm)
        VStack(alignment: .leading, spacing: 0) {

            // Header row
            HStack(alignment: .center) {
                Label("Paste Email", systemImage: "envelope.open.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if vm.hasResult {
                    Button {
                        withAnimation(.appCrisp) { vm.isEmailExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(vm.isEmailExpanded ? "Collapse" : "Edit email")
                                .font(.caption.weight(.medium))
                            Image(systemName: vm.isEmailExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.10))
                                .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.20), lineWidth: 1))
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                } else if !vm.emailText.isEmpty {
                    Button {
                        withAnimation(.appCrisp) { vm.emailText = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            if !vm.isEmailExpanded && !vm.emailText.isEmpty && !vm.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if vm.isHighlightExpanded {
                        Text(vm.buildHighlightedString(vm.emailText, spans: vm.highlights))
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(vm.buildHighlightedString(vm.emailText, spans: vm.highlights))
                            .font(.system(size: 13))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(Theme.textSecondary)
                            .mask(
                                LinearGradient(
                                    colors: [.black, .black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

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
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if vm.isEmailExpanded {
                if vm.emailText.isEmpty {
                    Text("Paste a job application email to extract its details.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

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
                        .frame(minHeight: vm.hasResult ? 90 : 180)
                        .font(.subheadline)
                        .focused($isEditorFocused)
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isEditorFocused ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08),
                                    lineWidth: isEditorFocused ? 1.5 : 1
                                )
                        )
                }
                .animation(.appFastOut, value: isEditorFocused)
                .animation(.appCrisp, value: vm.hasResult)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))

                Button {
                    withAnimation(.appFastOut) { vm.isButtonPressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.appFastOut) { vm.isButtonPressed = false }
                    }
                    vm.parseEmail(defaultResume: defaultResume) { scrollToResults = true }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isParsing {
                            ProgressView().tint(.white)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: vm.hasResult ? "arrow.clockwise.circle.fill" : "sparkles")
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text(vm.isParsing ? "Parsing…" : vm.hasResult ? "Re-parse" : "Parse Email")
                            .font(.system(size: 16, weight: .semibold))
                            .animation(.none, value: vm.isParsing)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(vm.isParseDisabled ? Color.secondary.opacity(0.3) : Color.accentColor)
                            .shadow(color: vm.isParseDisabled ? .clear : Color.accentColor.opacity(0.27), radius: 10, y: 3)
                    }
                }
                .scaleEffect(vm.isButtonPressed ? AppAnimations.pressScale : 1.0)
                .disabled(vm.isParseDisabled)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .glassCard()
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 20)
    }
}
