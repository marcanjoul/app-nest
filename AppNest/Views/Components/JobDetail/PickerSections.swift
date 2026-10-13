import SwiftUI

struct TypePickerSection: View {
    @Binding var type: ApplicationType?
    var isEmbedded = false

    var body: some View {
        ChoiceSection(title: "Job type", icon: "list.bullet", selection: .single($type),
                      options: ApplicationType.allCases, isEmbedded: isEmbedded,
                      isRequired: !isEmbedded, color: { $0.color }, symbol: { $0.iconName })
    }
}

struct StatusPickerSection: View {
    @Binding var status: ApplicationStatus?
    var isEmbedded = false

    var body: some View {
        ChoiceSection(title: "Status", icon: "rectangle.and.hand.point.up.left.fill", selection: .single($status),
                      options: ApplicationStatus.allCases, isEmbedded: isEmbedded,
                      isRequired: !isEmbedded, color: { $0.color }, symbol: { $0.iconName })
    }
}

/// Multi-select — a co-op or internship can span two seasons (Summer + Fall).
struct SeasonPickerSection: View {
    @Binding var seasons: [ApplicationSeason]
    var isEmbedded = false

    var body: some View {
        ChoiceSection(title: "Season", icon: "sun.snow.fill", selection: .multiple($seasons),
                      options: ApplicationSeason.allCases, isEmbedded: isEmbedded,
                      color: { $0.color }, symbol: { $0.iconName })
    }
}

/// What a `ChoiceSection` writes to: one optional value, or a list.
enum ChoiceSelection<Option: Hashable> {
    case single(Binding<Option?>)
    case multiple(Binding<[Option]>)

    func contains(_ option: Option) -> Bool {
        switch self {
        case .single(let b):   return b.wrappedValue == option
        case .multiple(let b): return b.wrappedValue.contains(option)
        }
    }

    /// Tapping a selected pill clears it; tapping another selects it (and, single-select, replaces).
    func toggle(_ option: Option) {
        switch self {
        case .single(let b):
            b.wrappedValue = b.wrappedValue == option ? nil : option
        case .multiple(let b):
            if let i = b.wrappedValue.firstIndex(of: option) { b.wrappedValue.remove(at: i) }
            else { b.wrappedValue.append(option) }
        }
    }
}

private struct ChoiceSection<Option: Hashable & RawRepresentable>: View where Option.RawValue == String {
    let title: String
    let icon: String
    let selection: ChoiceSelection<Option>
    let options: [Option]
    var isEmbedded: Bool
    var isRequired = false
    let color: (Option) -> Color
    let symbol: (Option) -> String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Selected pills move to the head of the row so the current choice is always the one
    /// you can see, however far down `allCases` it sits.
    private var orderedOptions: [Option] {
        options.filter(selection.contains) + options.filter { !selection.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: icon, title: title, isRequired: isRequired)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(orderedOptions, id: \.self) { option in
                            SelectablePill(option: option, isSelected: selection.contains(option),
                                           color: color(option), icon: symbol(option)) {
                                withAnimation(reduceMotion ? nil : .appCrisp) {
                                    selection.toggle(option)
                                }
                                AppHaptics.shared.light()
                            }
                            .id(option)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                // Reordering alone leaves the row scrolled wherever the tap happened.
                .onChange(of: orderedOptions) { _, _ in
                    guard let first = orderedOptions.first else { return }
                    withAnimation(reduceMotion ? nil : .appSmooth) {
                        proxy.scrollTo(first, anchor: .leading)
                    }
                }
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
