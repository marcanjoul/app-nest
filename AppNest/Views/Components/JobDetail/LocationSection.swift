import SwiftUI

struct LocationSection: View {
    @Binding var workMode: WorkMode?
    @Binding var location: String

    private var showLocationField: Bool {
        workMode == .hybrid || workMode == .onSite
    }

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
                                    let next: WorkMode? = workMode == mode ? nil : mode
                                    workMode = next
                                    if next == .remote || next == nil {
                                        location = ""
                                    }
                                }
                                AppHaptics.shared.light()
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            if showLocationField {
                TextField("City, state, or country", text: $location)
                    .appFont(15)
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.appCrisp, value: showLocationField)
        .padding(16)
        .glassCard()
    }
}
