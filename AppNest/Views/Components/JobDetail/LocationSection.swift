import SwiftUI

struct LocationSection: View {
    @Binding var workMode: WorkMode?
    @Binding var location: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "mappin.circle.fill", title: "Location")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WorkMode.allCases, id: \.self) { mode in
                        SelectablePill(
                            option: mode,
                            isSelected: workMode == mode,
                            color: mode.color,
                            icon: mode.iconName,
                            onTap: {
                                withAnimation(.appCrisp) {
                                    workMode = (workMode == mode ? nil : mode)
                                }
                                AppHaptics.shared.light()
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            TextField("City, state, or country", text: $location)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .tint(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        }
                }
        }
        .padding(16)
        .glassCard()
    }
}
