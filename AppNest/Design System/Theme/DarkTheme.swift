import SwiftUI

enum DarkTheme {

    // MARK: - Background

    static let background = Color(UIColor.systemBackground)

    // MARK: - Glass Card Modifier

    static let cardRadius: CGFloat = 20

    // MARK: - Card Fill (adaptive)

    static let cardFill: Color = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.secondarySystemGroupedBackground
            : UIColor.systemGray6
    })

    static let cardBorder: Color = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.separator.withAlphaComponent(0.4)
            : UIColor.separator.withAlphaComponent(0.7)
    })

    // MARK: - Text Colors

    static let textPrimary   = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary  = Color(UIColor.tertiaryLabel)

    // MARK: - Status Styles

    struct StatusStyle {
        let tintColor:   Color
        let fillColor:   Color
        let borderColor: Color
        let iconName:    String
    }

    static func statusStyle(for status: ApplicationStatus) -> StatusStyle {
        switch status {
        case .toApply:
            let c = Color(red: 0.58, green: 0.62, blue: 0.82)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "plus.circle.fill"
            )
        case .applied:
            let c = Color(red: 0.35, green: 0.65, blue: 0.96)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "paperplane.fill"
            )
        case .interview:
            let c = Color(red: 0.96, green: 0.73, blue: 0.28)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "person.2.fill"
            )
        case .offer:
            let c = Color(red: 0.30, green: 0.80, blue: 0.45)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "checkmark.seal.fill"
            )
        case .rejected:
            let c = Color(red: 0.93, green: 0.38, blue: 0.44)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "xmark.circle.fill"
            )
        }
    }

    // MARK: - Type Tag Style

    static let typeTagFill   = Color(UIColor.tertiarySystemFill)
    static let typeTagRadius: CGFloat = 8

    // MARK: - Stat Chip Style

    static let statChipFill   = Color(UIColor.secondarySystemGroupedBackground)
    static let statChipRadius: CGFloat = 16

    // MARK: - Company Avatar Gradients

    static let avatarColors: [Color] = [
        Color(red: 0.36, green: 0.66, blue: 0.96),
        Color(red: 0.96, green: 0.73, blue: 0.28),
        Color(red: 0.30, green: 0.80, blue: 0.45),
        Color(red: 0.93, green: 0.38, blue: 0.44),
        Color(red: 0.62, green: 0.52, blue: 0.96),
        Color(red: 0.96, green: 0.52, blue: 0.62),
    ]

    static func avatarGradient(for name: String) -> Color {
        avatarColors[abs(name.hashValue) % avatarColors.count]
    }

    // MARK: - Section Labels

    static let sectionLabelSize:    CGFloat = 11
    static let sectionLabelSpacing: CGFloat = 1.2
}

// MARK: - Glass Card ViewModifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var shadowOpacity: Double = 0.10
    var fillOpacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DarkTheme.cardFill)
                    .opacity(fillOpacity)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(DarkTheme.cardBorder.opacity(fillOpacity), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, y: 3)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, shadowOpacity: Double = 0.10, fillOpacity: Double = 1.0) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity, fillOpacity: fillOpacity))
    }
}

// MARK: - Ambient Background

struct AmbientBackground: View {
    var body: some View {
        Color(UIColor.systemBackground)
            .ignoresSafeArea()
    }
}
