import SwiftUI

enum DarkTheme {

    // MARK: - Background

    static let background = Color(UIColor.systemBackground)

    // MARK: - Glass Card Modifier

    static let cardRadius: CGFloat = 20

    // MARK: - Card Fill (calibrated)

    static let cardFill: Color = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 0.85) // Tinted dark gray
            : UIColor.secondarySystemGroupedBackground
    })

    static let cardBorder: Color = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.04) // Even subtler for light mode
    })

    // MARK: - Text Colors

    static let textPrimary   = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary  = Color(UIColor.tertiaryLabel)

    // MARK: - Status Styles (high-end palette)

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
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18),
                iconName: "plus.circle.fill"
            )
        case .applied:
            let c = Color(red: 0.30, green: 0.60, blue: 0.94) // More sophisticated blue
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18),
                iconName: "paperplane.fill"
            )
        case .interview:
            let c = Color(red: 0.96, green: 0.65, blue: 0.14) // Balanced amber
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18),
                iconName: "person.2.fill"
            )
        case .offer:
            let c = Color(red: 0.30, green: 0.80, blue: 0.45) // Success green
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18),
                iconName: "checkmark.seal.fill"
            )
        case .rejected:
            let c = Color(red: 0.93, green: 0.33, blue: 0.40) // Softened red
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18),
                iconName: "xmark.circle.fill"
            )
        }
    }

    // MARK: - Type Tag Style

    static let typeTagFill   = Color.primary.opacity(0.05)
    static let typeTagRadius: CGFloat = 10

    // MARK: - Stat Chip Style

    static let statChipFill   = Color(UIColor.secondarySystemGroupedBackground)
    static let statChipRadius: CGFloat = 18

    // MARK: - Company Avatar Gradients (calibrated)

    static let avatarColors: [Color] = [
        Color(red: 0.36, green: 0.66, blue: 0.96),
        Color(red: 0.96, green: 0.73, blue: 0.28),
        Color(red: 0.30, green: 0.80, blue: 0.45),
        Color(red: 0.93, green: 0.38, blue: 0.44),
        Color(red: 0.62, green: 0.52, blue: 0.96),
        Color(red: 0.96, green: 0.52, blue: 0.62),
    ]

    static func avatarGradient(for name: String) -> LinearGradient {
        let hash = abs(name.hashValue)
        let color = avatarColors[hash % avatarColors.count]
        return LinearGradient(
            colors: [color.opacity(0.85), color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Section Labels

    static let sectionLabelSize:    CGFloat = 11
    static let sectionLabelSpacing: CGFloat = 0.8 // Tighter tracking for high-end feel
}

// MARK: - Glass Card ViewModifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var shadowOpacity: Double = 0.08 // Softer shadow
    var fillOpacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial) // Better glass effect
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(DarkTheme.cardFill.opacity(fillOpacity))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(DarkTheme.cardBorder.opacity(fillOpacity), lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 12, y: 4) // Deeper but softer
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, shadowOpacity: Double = 0.08, fillOpacity: Double = 1.0) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity, fillOpacity: fillOpacity))
    }
}

// MARK: - Ambient Background

struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            
            // Suble ambient glow in top right
            GeometryReader { geo in
                let size = max(geo.size.width, geo.size.height) * 1.2
                RadialGradient(
                    colors: [
                        Color.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.05),
                        Color.accentColor.opacity(0)
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: size
                )
                .offset(x: geo.size.width * 0.2, y: -geo.size.height * 0.1)
            }
        }
        .ignoresSafeArea()
    }
}
