import SwiftUI

// MARK: - Type Scale

/// The app's type scale: six roles, each about 1.15–1.3× the next. Text names a role, never a
/// point size; icons still take exact sizes through `appFont(_ size:)`. Each role scales with
/// Dynamic Type along its matching system text style, so captions grow like captions.
enum AppTextStyle {
    case largeTitle, title, headline, body, footnote, caption

    var size: CGFloat {
        switch self {
        case .largeTitle: 34
        case .title:      22
        case .headline:   17
        case .body:       15
        case .footnote:   13
        case .caption:    11
        }
    }

    /// The system style whose Dynamic Type curve this role follows (same base size).
    var textStyle: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title:      .title2
        case .headline:   .headline
        case .body:       .subheadline
        case .footnote:   .footnote
        case .caption:    .caption2
        }
    }

    /// Titles and headlines use the display face (`Theme.displayFont`); smaller text stays SF.
    var usesDisplayFont: Bool { self == .largeTitle || self == .title || self == .headline }
}

// MARK: - Scaled Font

struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight
    private let usesDisplayFont: Bool

    init(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body, usesDisplayFont: Bool = false) {
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.usesDisplayFont = usesDisplayFont
    }

    func body(content: Content) -> some View {
        let font = (usesDisplayFont ? Theme.displayFont(size: scaledSize, weight: weight) : nil)
            ?? .system(size: scaledSize, weight: weight)
        return content.font(font)
            .environment(\.appIconSize, scaledSize)
    }
}

extension View {
    /// Text: pick a role from the type scale.
    func appFont(_ style: AppTextStyle, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledSystemFont(style.size, weight: weight, relativeTo: style.textStyle,
                                  usesDisplayFont: style.usesDisplayFont))
    }

    /// Icons and other graphics that need an exact size.
    func appFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledSystemFont(size, weight: weight))
    }
}

// MARK: - Surface

struct Surface: ViewModifier {
    var cornerRadius: CGFloat = 20
    var shadowOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Theme.cardBorder, lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(shadowOpacity * 0.2), radius: 3, y: 1)
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
                        Theme.accent.opacity(isChanged ? 0.35 : 0),
                        lineWidth: isChanged ? 1.5 : 0
                    )
                    .animation(.appSmooth, value: isChanged)
            }
            .background {
                if isChanged {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(Theme.accent.opacity(0.02))
                }
            }
    }
}

extension View {
    func changedHighlight(_ isChanged: Bool) -> some View {
        modifier(ChangedHighlight(isChanged: isChanged))
    }
    
    func surface(cornerRadius: CGFloat = 20, shadowOpacity: Double = 0.08) -> some View {
        modifier(Surface(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
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
                    AppIcon("chevron.down")
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
