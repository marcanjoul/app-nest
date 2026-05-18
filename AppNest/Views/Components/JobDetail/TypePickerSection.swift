import SwiftUI

struct TypePickerSection: View {
    @Binding var type: ApplicationType?

    private var orderedOptions: [ApplicationType] {
        if let selected = type {
            return [selected] + ApplicationType.allCases.filter { $0 != selected }
        }
        return ApplicationType.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "list.bullet", title: "Job Type", isRequired: true)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(orderedOptions, id: \.self) { option in
                            SelectablePill(
                                option: option,
                                isSelected: option == type,
                                color: option.color,
                                icon: option.iconName,
                                onTap: {
                                    withAnimation(.appCrisp) {
                                        type = (type == option ? nil : option)
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
                .onChange(of: type) { _, _ in
                    if let first = orderedOptions.first {
                        withAnimation(.appSmooth) { proxy.scrollTo(first, anchor: .leading) }
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}
