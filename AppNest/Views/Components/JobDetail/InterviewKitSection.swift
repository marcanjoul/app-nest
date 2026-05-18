import SwiftUI

struct InterviewKitSection: View {
    @Binding var companyResearch: String
    @Binding var interviewNotes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(icon: "person.wave.2.fill", title: "Interview Kit")

            VStack(alignment: .leading, spacing: 8) {
                subLabel(icon: "building.2.fill", title: "Company Research")
                noteEditor(
                    text: $companyResearch,
                    placeholder: "Mission, culture, recent news, why you're excited…"
                )
            }

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 8) {
                subLabel(icon: "mic.fill", title: "Interview Prep")
                noteEditor(
                    text: $interviewNotes,
                    placeholder: "STAR stories, questions to ask, talking points…"
                )
            }
        }
        .padding(16)
        .glassCard()
    }

    @ViewBuilder
    private func subLabel(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DarkTheme.textSecondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DarkTheme.textSecondary)
        }
    }

    @ViewBuilder
    private func noteEditor(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
            }
            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 100)
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
    }
}
