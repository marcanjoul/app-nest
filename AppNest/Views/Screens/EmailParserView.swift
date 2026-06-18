import SwiftUI
import SwiftData

struct EmailParserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    var initialText: String? = nil

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
                        if vm.isParsing {
                            ResultsCardSkeleton()
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                        }
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
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .dismissKeyboardToolbar()
        .onAppear {
            withAnimation(.appSmooth.delay(0.1)) { cardAppeared = true }
            if let text = initialText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                vm.emailText = text
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    vm.parseEmail(defaultResume: defaultResume) { scrollToResults = true }
                }
            }
        }
        .task(id: vm.editCompany) {
            await vm.fetchLogo(isDark: colorScheme == .dark)
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
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if vm.hasResult && !vm.isEmailExpanded {
                    Button {
                        vm.backToEdit()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isEditorFocused = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .appFont(11, weight: .semibold)
                            Text("Edit email")
                                .font(.caption.weight(.medium))
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
                            .appFont(18)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            if !vm.isEmailExpanded && !vm.emailText.isEmpty && !vm.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if vm.isHighlightExpanded {
                        Text(vm.buildHighlightedString(vm.emailText, spans: vm.highlights))
                            .appFont(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(vm.buildHighlightedString(vm.emailText, spans: vm.highlights))
                            .appFont(13)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(Theme.textSecondary)
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
                        Image(systemName: vm.hasResult ? "arrow.clockwise.circle.fill" : "sparkles")
                            .transition(.scale.combined(with: .opacity))
                        Text(vm.hasResult ? "Re-parse" : "Parse Email")
                            .appFont(16, weight: .semibold)
                            .animation(.none, value: vm.isParsing)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(vm.isParseDisabled ? Color.secondary.opacity(0.3) : Color.accentColor)
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
