import SwiftUI

/// An optional form section that folds down to its own header row. It's an accordion like the
/// Add screen's cards: the section is always rendered, and its height animates between the
/// header row and its full size, so opening and closing grow/shrink the same card instead of
/// swapping one view for another. Sections that already hold something start open, so
/// editing a job never hides data.
// ponytail: folds by clipping the section's own card to its header row. Every wrapped section
// starts with a bare SectionLabel under 16pt card padding, so `headerHeight` is that row; a
// section that grows a trailing header control needs the chevron revisited.
struct CollapsibleSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    @State private var isExpanded: Bool
    @State private var contentHeight: CGFloat = 0
    @ScaledMetric private var headerHeight: CGFloat = 48   // 16 padding + label + 16 padding

    private let cardShape = RoundedRectangle(cornerRadius: 20, style: .continuous)   // Surface's radius

    init(icon: String, title: String, startsExpanded: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.icon = icon
        self.title = title
        self.content = content
        _isExpanded = State(initialValue: startsExpanded)
    }

    /// Before the first measurement an open section takes its natural height.
    private var visibleHeight: CGFloat? {
        isExpanded ? (contentHeight > 0 ? contentHeight : nil) : headerHeight
    }

    var body: some View {
        content()
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            // Folded fields are out of sight; keep VoiceOver out of them too.
            .accessibilityHidden(!isExpanded)
            .frame(height: visibleHeight, alignment: .top)
            .clipShape(cardShape)
            // Clipping cuts the card's bottom hairline; redraw it while folded.
            .overlay { cardShape.strokeBorder(Theme.cardBorder, lineWidth: 1).opacity(isExpanded ? 0 : 1) }
            // Folded: the whole card opens it. Open: only the header row closes it, so the
            // section's own controls stay tappable.
            .overlay(alignment: .top) {
                Button {
                    withAnimation(.appSmooth) { isExpanded.toggle() }
                    AppHaptics.shared.light()
                } label: {
                    HStack {
                        Spacer()
                        // Same chevron-in-a-circle as the Add screen's expandable cards.
                        AppIcon("chevron.down")
                            .appFont(12, weight: .bold)
                            .foregroundStyle(Theme.textSecondary.opacity(0.55))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                            .rotationEffect(.degrees(isExpanded ? -180 : 0))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: headerHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse \(title)" : "Expand \(title)")
            }
            .animation(.appSmooth, value: isExpanded)
    }
}
