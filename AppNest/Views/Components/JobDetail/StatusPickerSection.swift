import SwiftUI

struct StatusPickerSection: View {
    @Binding var status: ApplicationStatus?
    var isEmbedded: Bool = false

    private var orderedOptions: [ApplicationStatus] {
        if let selected = status {
            return [selected] + ApplicationStatus.allCases.filter { $0 != selected }
        }
        return ApplicationStatus.allCases
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
            SectionLabel(icon: "rectangle.and.hand.point.up.left.fill", title: "Status", isRequired: !isEmbedded)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(orderedOptions, id: \.self) { option in
                            SelectablePill(
                                option: option,
                                isSelected: option == status,
                                color: option.color,
                                icon: option.iconName,
                                onTap: {
                                    withAnimation(.appCrisp) {
                                        status = (status == option ? nil : option)
                                    }
                                    AppHaptics.shared.light()
                                }
                            )
                            .id(option)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .onChange(of: status) { _, _ in
                    if let first = orderedOptions.first {
                        withAnimation(.appSmooth) { proxy.scrollTo(first, anchor: .leading) }
                    }
                }
            }
        }
    }
}
