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
        let gradient:    LinearGradient
    }

    static func statusStyle(for status: ApplicationStatus) -> StatusStyle {
        switch status {
        case .toApply:
            let c = Color(red: 0.58, green: 0.62, blue: 0.82)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "plus.circle.fill",
                gradient: LinearGradient(colors: [c.opacity(0.22), c.opacity(0.07)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .applied:
            let c = Color(red: 0.35, green: 0.65, blue: 0.96)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "paperplane.fill",
                gradient: LinearGradient(colors: [c.opacity(0.22), c.opacity(0.07)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .interview:
            let c = Color(red: 0.96, green: 0.73, blue: 0.28)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "person.2.fill",
                gradient: LinearGradient(colors: [c.opacity(0.22), c.opacity(0.07)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .offer:
            let c = Color(red: 0.30, green: 0.80, blue: 0.45)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "checkmark.seal.fill",
                gradient: LinearGradient(colors: [c.opacity(0.22), c.opacity(0.07)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .rejected:
            let c = Color(red: 0.93, green: 0.38, blue: 0.44)
            return StatusStyle(
                tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.28),
                iconName: "xmark.circle.fill",
                gradient: LinearGradient(colors: [c.opacity(0.22), c.opacity(0.07)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
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

    static let avatarGradients: [LinearGradient] = [
        LinearGradient(colors: [Color(red: 0.36, green: 0.66, blue: 0.96), Color(red: 0.20, green: 0.50, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.96, green: 0.73, blue: 0.28), Color(red: 0.80, green: 0.57, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.30, green: 0.80, blue: 0.45), Color(red: 0.18, green: 0.64, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.93, green: 0.38, blue: 0.44), Color(red: 0.76, green: 0.22, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.62, green: 0.52, blue: 0.96), Color(red: 0.46, green: 0.36, blue: 0.82)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.96, green: 0.52, blue: 0.62), Color(red: 0.80, green: 0.36, blue: 0.46)], startPoint: .topLeading, endPoint: .bottomTrailing),
    ]

    static func avatarGradient(for name: String) -> LinearGradient {
        avatarGradients[abs(name.hashValue) % avatarGradients.count]
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
                    .fill(.ultraThinMaterial)
                    .opacity(fillOpacity)
                    .overlay {
                        // Subtle top-leading shimmer — visible in dark, barely-there in light
                        LinearGradient(
                            colors: [Color.white.opacity(0.07 * fillOpacity), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                    .overlay {
                        // Adaptive border: white in dark mode, near-black in light mode
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.09 * fillOpacity), lineWidth: 1)
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
        ZStack {
            Color(UIColor.systemBackground)
            RadialGradient(
                colors: [Color(red: 0.12, green: 0.20, blue: 0.62).opacity(0.30), .clear],
                center: UnitPoint(x: 0.05, y: 0.02),
                startRadius: 0, endRadius: 440
            )
            RadialGradient(
                colors: [Color(red: 0.40, green: 0.10, blue: 0.60).opacity(0.20), .clear],
                center: UnitPoint(x: 0.95, y: 0.98),
                startRadius: 0, endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}
