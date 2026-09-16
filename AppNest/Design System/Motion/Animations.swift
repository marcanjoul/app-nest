import SwiftUI

// MARK: - App-wide Animations

extension Animation {
    /// Short eased transition for layout changes.
    static var appSmooth: Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.25)
    }
    
    /// Immediate feedback for small interactions.
    static var appCrisp: Animation {
        .timingCurve(0.23, 1.0, 0.32, 1.0, duration: 0.18)
    }

    /// Snappy spring with a subtle bounce for success/celebration states.
    static var appBouncy: Animation {
        .timingCurve(0.34, 1.35, 0.64, 1.0, duration: 0.50)
    }
    
    /// Shared timing for expanding panels.
    static var appBubbly: Animation {
        .appSmooth
    }
    
    /// Gentle, fluid ease for slower decorative moves.
    static var appFastOut: Animation {
        .timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.28)
    }
}

enum AppAnimations {
    static let pressScale: CGFloat = 0.96
    
    
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

// MARK: - Global Button Styles

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? AppAnimations.pressScale : 1.0)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct CardPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.85), value: configuration.isPressed)
    }
}
