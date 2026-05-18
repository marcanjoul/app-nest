import SwiftUI

// MARK: - App-wide Animations
enum AppAnimations {
    static let pressScale: CGFloat = 0.96
    
    static var springDefault: Animation {
        .spring(response: 0.35, dampingFraction: 0.82)
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
