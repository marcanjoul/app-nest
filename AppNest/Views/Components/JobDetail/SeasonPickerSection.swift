import SwiftUI

struct SeasonPickerSection: View {
    @Binding var season: ApplicationSeason?

    private var orderedOptions: [ApplicationSeason] {
        if let selected = season {
            return [selected] + ApplicationSeason.allCases.filter { $0 != selected }
        }
        return ApplicationSeason.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "sun.snow.fill", title: "Season")

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(orderedOptions, id: \.self) { option in
                            SelectablePill(
                                option: option,
                                isSelected: option == season,
                                color: option.color,
                                icon: option.iconName,
                                onTap: {
                                    withAnimation(.appCrisp) {
                                        season = (season == option ? nil : option)
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
                .onChange(of: season) { _, _ in
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
