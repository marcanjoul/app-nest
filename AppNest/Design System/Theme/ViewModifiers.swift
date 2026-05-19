import SwiftUI

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var shadowOpacity: Double = 0.08
    var fillOpacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.cardFill.opacity(fillOpacity))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Theme.cardBorder.opacity(fillOpacity), lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 12, y: 4)
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

            GeometryReader { geo in
                let size = max(geo.size.width, geo.size.height) * 1.4
                RadialGradient(
                    colors: [
                        Color.accentColor.opacity(colorScheme == .dark ? 0.09 : 0.06),
                        Color.accentColor.opacity(0)
                    ],
                    center: UnitPoint(x: 0.9, y: 0.0),
                    startRadius: 0,
                    endRadius: size
                )
            }
        }
        .ignoresSafeArea()
    }
}
