import SwiftUI

struct JobNotesSection: View {
    @Binding var jobNotes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "square.and.pencil", title: "Notes")

            ZStack(alignment: .topLeading) {
                if jobNotes.isEmpty {
                    Text("Add notes about this job…")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                }
                TextEditor(text: $jobNotes)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 130)
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
        .padding(16)
        .glassCard()
    }
}
