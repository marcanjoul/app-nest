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

// MARK: - Global Button Styles

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppAnimations.pressScale : 1.0)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
