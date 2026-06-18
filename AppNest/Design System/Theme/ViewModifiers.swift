import SwiftUI

// MARK: - Scaled Font

struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight

    init(_ size: CGFloat, weight: Font.Weight = .regular) {
        self._scaledSize = ScaledMetric(wrappedValue: size)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize, weight: weight))
    }
}

extension View {
    func appFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledSystemFont(size, weight: weight))
    }
}

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var shadowOpacity: Double = 0.08
    var fillOpacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Outer Bezel Enclosure
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Theme.background)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Theme.cardBorder.opacity(fillOpacity), lineWidth: 1)
                        }
                    
                    // Inner Concentric Core
                    RoundedRectangle(cornerRadius: max(4, cornerRadius - 5), style: .continuous)
                        .fill(.ultraThinMaterial)
                        .padding(5)
                    RoundedRectangle(cornerRadius: max(4, cornerRadius - 5), style: .continuous)
                        .fill(Theme.cardFill.opacity(fillOpacity))
                        .padding(5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: max(4, cornerRadius - 5), style: .continuous)
                        .strokeBorder(Theme.cardBorder.opacity(fillOpacity * 0.5), lineWidth: 0.8)
                        .padding(5)
                }
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 12, y: 4)
    }
}

// MARK: - Changed Highlight

struct ChangedHighlight: ViewModifier {
    let isChanged: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(
                        Color.accentColor.opacity(isChanged ? 0.35 : 0),
                        lineWidth: isChanged ? 1.5 : 0
                    )
                    .animation(.appSmooth, value: isChanged)
            }
            .background {
                if isChanged {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(0.02))
                }
            }
    }
}

extension View {
    func changedHighlight(_ isChanged: Bool) -> some View {
        modifier(ChangedHighlight(isChanged: isChanged))
    }
    
    func glassCard(cornerRadius: CGFloat = 20, shadowOpacity: Double = 0.08, fillOpacity: Double = 1.0) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity, fillOpacity: fillOpacity))
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Ambient Background

struct AmbientBackground: View {
    var body: some View {
        Theme.background
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

struct DismissKeyboardToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    #if canImport(UIKit)
                    UIApplication.shared.dismissKeyboard()
                    #endif
                } label: {
                    Image(systemName: "chevron.down")
                        .appFont(14, weight: .semibold)
                }
                .accessibilityLabel("Dismiss keyboard")
            }
        }
    }
}

extension View {
    func dismissKeyboardToolbar() -> some View {
        modifier(DismissKeyboardToolbar())
    }
}

// MARK: - Swipe-Back Gesture (re-enabled when nav bar is hidden)

// SwiftUI disables the interactive pop gesture whenever the navigation bar is hidden.
// Overriding the delegate here restores it for every NavigationStack push in the app.
#if canImport(UIKit)
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
#endif
