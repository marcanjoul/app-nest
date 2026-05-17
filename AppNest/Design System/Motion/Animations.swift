import SwiftUI

struct AppAnimations {
    /// A crisp spring for fast UI interactions (e.g. search, filters).
    /// Starts fast, settles quickly.
    static let crisp = Animation.spring(response: 0.3, dampingFraction: 0.82)
    
    /// A smoother, more elegant spring for larger transitions (e.g. view appear, sheet entry).
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.85)
    
    /// A bouncy spring for playful interactions (e.g. FAB, celebratory moments).
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.65)
    
    /// Standard ease-out for quick feedback.
    static let fastOut = Animation.easeOut(duration: 0.16)
    
    /// A standard scale for active states (buttons, cards).
    /// 0.97 is the "magic number" for subtle but noticeable feedback.
    static let pressScale: CGFloat = 0.97
}

extension Animation {
    static var appCrisp: Animation { AppAnimations.crisp }
    static var appSmooth: Animation { AppAnimations.smooth }
    static var appBouncy: Animation { AppAnimations.bouncy }
    static var appFastOut: Animation { AppAnimations.fastOut }
}

/// A button style that scales the label down slightly when pressed.
/// Centralized to ensure consistent press feedback across the app.
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = AppAnimations.pressScale
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.appFastOut, value: configuration.isPressed)
    }
}
