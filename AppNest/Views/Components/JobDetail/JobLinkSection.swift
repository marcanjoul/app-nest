import SwiftUI

struct JobLinkSection: View {
    @Binding var jobURL: String
    var isEmbedded: Bool = false
    @Environment(\.openURL) private var openURL

    private var resolvedURL: URL? {
        let trimmed = jobURL.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let str = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        return URL(string: str)
    }

    var body: some View {
        Group {
            if isEmbedded {
                contentStack
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                            }
                    }
            } else {
                contentStack
                    .padding(16)
                    .glassCard()
            }
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "link", title: "Job Link")

            HStack(spacing: 10) {
                TextField("Paste job posting URL…", text: $jobURL)
                    .font(.subheadline)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.primary)

                if resolvedURL != nil {
                    Button {
                        if let url = resolvedURL { openURL(url) }
                    } label: {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
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
            .animation(.appCrisp, value: resolvedURL != nil)
        }
    }
}
