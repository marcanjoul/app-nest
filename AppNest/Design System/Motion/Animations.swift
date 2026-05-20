import SwiftUI

// MARK: - App-wide Animations

extension Animation {
    /// Smooth, natural spring for primary transitions.
    static var appSmooth: Animation {
        .spring(response: 0.35, dampingFraction: 0.82)
    }
    
    /// Snappy, immediate spring for small interactions.
    static var appCrisp: Animation {
        .spring(response: 0.22, dampingFraction: 0.85)
    }

    /// Snappy spring with a subtle bounce for success/celebration states.
    static var appBouncy: Animation {
        .spring(response: 0.38, dampingFraction: 0.55)
    }
    
    /// Bubbly, liquidy spring for dramatic expansions. Highly damped to prevent screen overflow.
    static var appBubbly: Animation {
        .spring(response: 0.40, dampingFraction: 0.65)
    }
    
    /// Gentle, fluid ease for slower decorative moves.
    static var appFastOut: Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: 0.28)
    }
}

enum AppAnimations {
    static let pressScale: CGFloat = 0.96
    
    static var springDefault: Animation {
        .appSmooth
    }
    
    static var springBouncy: Animation {
        .spring(response: 0.45, dampingFraction: 0.65)
    }
}

// MARK: - Geometry Effects

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat = 0

    func effectValue(size: CGSize) -> ProjectionTransform {
        let amplitude: CGFloat = 8
        let translation = amplitude * sin(animatableData * .pi * 4) * (1 - animatableData)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.3), location: 0.3),
                            .init(color: .white.opacity(0.5), location: 0.5),
                            .init(color: .white.opacity(0.3), location: 0.7),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 2)
                    .offset(x: -proxy.size.width + (proxy.size.width * 2 * phase))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Adds a shimmering effect, typically used for skeleton loading.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Global Button Styles

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppAnimations.pressScale : 1.0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.05 : 0.12),
                radius: configuration.isPressed ? 2 : 8,
                y: configuration.isPressed ? 1 : 4
            )
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
