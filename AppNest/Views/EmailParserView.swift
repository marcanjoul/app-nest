import SwiftUI
import SwiftData

struct EmailParserView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var emailText    = ""
    @State private var parsedResult: EmailParser.ParsedResult? = nil
    @State private var isParsing    = false

    private let parser = EmailParser()

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 20) {

                    // Input card
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
                        }
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        }

                        Button { parseEmail() } label: {
                            HStack(spacing: 8) {
                                if isParsing {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isParsing ? "Parsing…" : "Parse Email")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                let disabled = emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing
                                Capsule()
                                    .fill(disabled ? Color.secondary.opacity(0.3) : Color.accentColor)
                                    .overlay {
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.20), Color.clear],
                                            startPoint: .top, endPoint: .center
                                        )
                                        .clipShape(Capsule())
                                    }
                                    .shadow(color: disabled ? .clear : Color.accentColor.opacity(0.27), radius: 10, y: 3)
                            }
                        }
                        .disabled(emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing)
                    }
                    .padding(18)
                    .glassCard()

                    // Results card
                    if let result = parsedResult {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Extracted Details", systemImage: "checkmark.seal.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.30, green: 0.80, blue: 0.45))

                            VStack(spacing: 10) {
                                ParsedRow(icon: "building.2",  label: "Company",  value: result.companyName ?? "Not detected")
                                ParsedRow(icon: "briefcase",   label: "Position", value: result.position ?? "Not detected")
                                ParsedRow(icon: "flag",        label: "Status",   value: result.status?.rawValue ?? "Not detected")
                                ParsedRow(icon: "calendar",    label: "Date",     value: result.dateApplied.map {
                                    $0.formatted(date: .abbreviated, time: .omitted)
                                } ?? "Not detected")
                            }

                            Button { saveApplication() } label: {
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
                .padding()
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
    }

    // MARK: - Actions

    private func parseEmail() {
        isParsing = true
        parsedResult = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            parsedResult = parser.parse(emailText)
            isParsing = false
        }
    }

    private func saveApplication() {
        guard let result = parsedResult else { return }
        modelContext.insert(JobApplication(
            companyName: result.companyName ?? "Unknown Company",
            position:    result.position ?? "Unknown Position",
            status:      result.status ?? .applied,
            dateApplied: result.dateApplied ?? Date()
        ))
        emailText = ""
        parsedResult = nil
    }
}

// MARK: - Parsed Row

private struct ParsedRow: View {
    let icon:  String
    let label: String
    let value: String

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
    }
}
