import SwiftUI
import SwiftData

struct EmailParserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]

    @State private var emailText    = ""
    @State private var parsedResult: EmailParser.ParsedResult? = nil
    @State private var isParsing    = false
    @State private var cardAppeared = false
    @State private var isButtonPressed = false
    @FocusState private var isEditorFocused: Bool

    private let parser = EmailParser()

    private var defaultResume: ResumeDocument? {
        resumes.first(where: \.isDefault)
    }

    private var isParseDisabled: Bool {
        emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 20) {
                    inputCard

                    if let result = parsedResult {
                        ResultsCard(result: result, onSave: saveApplication)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding()
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: parsedResult != nil)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Parse Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1)) {
                cardAppeared = true
            }
        }
    }

    // MARK: - Input Card

    @ViewBuilder
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Paste Email", systemImage: "envelope.open.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DarkTheme.textPrimary)

            Text("Paste a job application confirmation email and AppNest extracts the details automatically.")
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textSecondary)

            ZStack(alignment: .topLeading) {
                if emailText.isEmpty {
                    Text("Paste your email here…")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $emailText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 180)
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
                                isEditorFocused
                                    ? Color.accentColor.opacity(0.55)
                                    : Color.primary.opacity(0.08),
                                lineWidth: isEditorFocused ? 1.5 : 1
                            )
                    )
            }
            .animation(.easeInOut(duration: 0.2), value: isEditorFocused)

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { isButtonPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { isButtonPressed = false }
                }
                parseEmail()
            } label: {
                HStack(spacing: 8) {
                    if isParsing {
                        ProgressView()
                            .tint(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "sparkles")
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(isParsing ? "Parsing…" : "Parse Email")
                        .font(.system(size: 16, weight: .semibold))
                        .animation(.none, value: isParsing)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                        .fill(isParseDisabled ? Color.secondary.opacity(0.3) : Color.accentColor)
                        .overlay {
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), Color.clear],
                                startPoint: .top, endPoint: .center
                            )
                            .clipShape(Capsule())
                        }
                        .shadow(color: isParseDisabled ? .clear : Color.accentColor.opacity(0.27), radius: 10, y: 3)
                }
            }
            .scaleEffect(isButtonPressed ? 0.96 : 1.0)
            .disabled(isParseDisabled)
        }
        .padding(18)
        .glassCard()
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 20)
    }

    // MARK: - Actions

    private func parseEmail() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isParsing = true
            parsedResult = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                parsedResult = parser.parse(emailText)
                isParsing = false
            }
        }
    }

    private func saveApplication() {
        guard let result = parsedResult else { return }
        let attached = defaultResume
        modelContext.insert(JobApplication(
            companyName: result.companyName ?? "Unknown Company",
            position:    result.position ?? "Unknown Position",
            status:      result.status ?? .applied,
            dateApplied: result.dateApplied ?? Date(),
            resumeFileName: attached?.fileName,
            resumeBookmark: attached?.bookmark,
            resumeID: attached?.id
        ))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            emailText = ""
            parsedResult = nil
        }
    }
}

// MARK: - Results Card

private struct ResultsCard: View {
    let result: EmailParser.ParsedResult
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Extracted Details", systemImage: "checkmark.seal.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.30, green: 0.80, blue: 0.45))

            VStack(spacing: 10) {
                ParsedRow(icon: "building.2", label: "Company",  value: result.companyName ?? "Not detected", index: 0)
                ParsedRow(icon: "briefcase",  label: "Position", value: result.position ?? "Not detected",    index: 1)
                ParsedRow(icon: "flag",       label: "Status",   value: result.status?.rawValue ?? "Not detected", index: 2)
                ParsedRow(icon: "calendar",   label: "Date",     value: result.dateApplied.map {
                    $0.formatted(date: .abbreviated, time: .omitted)
                } ?? "Not detected", index: 3)
            }

            Button { onSave() } label: {
                Label("Add to Applications", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        let c = Color(red: 0.30, green: 0.80, blue: 0.45)
                        Capsule()
                            .fill(c)
                            .overlay {
                                LinearGradient(colors: [Color.white.opacity(0.20), Color.clear], startPoint: .top, endPoint: .center)
                                    .clipShape(Capsule())
                            }
                            .shadow(color: c.opacity(0.27), radius: 10, y: 3)
                    }
            }
            .disabled(result.companyName == nil && result.position == nil)
        }
        .padding(18)
        .glassCard()
    }
}

// MARK: - Parsed Row

private struct ParsedRow: View {
    let icon:  String
    let label: String
    let value: String
    let index: Int

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(DarkTheme.textSecondary)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(DarkTheme.textPrimary)
            }
            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72).delay(Double(index) * 0.075)) {
                appeared = true
            }
        }
    }
}
