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
    var body: some View {
        Color(UIColor.systemBackground)
            .ignoresSafeArea()
    }
}

// MARK: - Keyboard Dismiss

#if canImport(UIKit)
extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif
