import SwiftUI

struct TypePickerSection: View {
    @Binding var type: ApplicationType?
    var isEmbedded = false

    var body: some View {
        ChoiceSection(title: "Job type", icon: "list.bullet", selection: $type,
                      options: ApplicationType.allCases, isEmbedded: isEmbedded,
                      isRequired: !isEmbedded, color: { $0.color }, symbol: { $0.iconName })
    }
}

struct StatusPickerSection: View {
    @Binding var status: ApplicationStatus?
    var isEmbedded = false

    var body: some View {
        ChoiceSection(title: "Status", icon: "rectangle.and.hand.point.up.left.fill", selection: $status,
                      options: ApplicationStatus.allCases, isEmbedded: isEmbedded,
                      isRequired: !isEmbedded, color: { $0.color }, symbol: { $0.iconName })
    }
}

struct SeasonPickerSection: View {
    @Binding var season: ApplicationSeason?
    var isEmbedded = false

    var body: some View {
        ChoiceSection(title: "Season", icon: "sun.snow.fill", selection: $season,
                      options: ApplicationSeason.allCases, isEmbedded: isEmbedded,
                      color: { $0.color }, symbol: { $0.iconName })
    }
}

private struct ChoiceSection<Option: Hashable & RawRepresentable>: View where Option.RawValue == String {
    let title: String
    let icon: String
    @Binding var selection: Option?
    let options: [Option]
    var isEmbedded: Bool
    var isRequired = false
    let color: (Option) -> Color
    let symbol: (Option) -> String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: icon, title: title, isRequired: isRequired)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        SelectablePill(option: option, isSelected: option == selection,
                                       color: color(option), icon: symbol(option)) {
                            withAnimation(reduceMotion ? nil : .appCrisp) {
                                selection = selection == option ? nil : option
                            }
                            AppHaptics.shared.light()
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(isEmbedded ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .if(!isEmbedded) { $0.surface() }
    }
}

/// Small uppercase row label with a leading SF Symbol icon used by the
/// `JobDetailView` form sections.
struct SectionLabel: View {
    let icon: String
    let title: String
    var isRequired: Bool = false
    var color: Color = Color.accentColor

    var body: some View {
        HStack(spacing: 6) {
            AppIcon(icon)
                .appFont(Theme.sectionLabelSize - 1, weight: .black)
                .foregroundStyle(color.opacity(0.8))
            
            HStack(spacing: 2) {
                Text(title)
                    .appFont(Theme.sectionLabelSize, weight: .semibold)
                    .tracking(0)
                    .textCase(nil)
                    .foregroundStyle(Theme.textSecondary)
                
                if isRequired {
                    Text("*")
                        .appFont(Theme.sectionLabelSize, weight: .bold)
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel("Required")
                }
            }
        }
    }
}
