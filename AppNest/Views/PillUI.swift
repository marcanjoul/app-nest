import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Universal Selectable Pill

/// Glassmorphic pill button for picking enum values in forms.
/// Selected: gradient fill + icon + white text.
/// Unselected: translucent tint fill + muted text.
struct SelectablePill<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let option: T
    let isSelected: Bool
    let color: Color
    var icon: String? = nil
    let onTap: () -> Void

    private var fillGradient: LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [color, color.opacity(0.78)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [color.opacity(0.22), color.opacity(0.07)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        HStack(spacing: isSelected ? 6 : 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 13 : 12, weight: .bold))
                    .foregroundStyle(isSelected ? .white : color)
            }
            Text(option.rawValue)
                .font(.system(size: isSelected ? 14 : 13, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? .white : color.opacity(0.88))
        }
        .padding(.horizontal, isSelected ? 14 : 12)
        .padding(.vertical, isSelected ? 9 : 8)
        .background(
            Capsule()
                .fill(fillGradient)
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : color.opacity(0.28),
                        lineWidth: isSelected ? 0 : 0.8
                    )
                )
        )
        .shadow(color: isSelected ? color.opacity(0.21) : .clear, radius: 6, y: 2)
        .onTapGesture {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onTap()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Resume Pill

/// Glass capsule pill for resume actions and attached resume states.
struct ResumePill: View {
    enum Style {
        case resume
        case attached
        case add
        case deleted
    }

    let title: String
    let style: Style
    var isSelected: Bool = false
    var isDefault: Bool = false
    var showsGlow: Bool = true
    var isLarge: Bool = false
    var action: (() -> Void)? = nil

    private var horizontalPadding: CGFloat {
        if isLarge { return 22 }
        return isSelected ? 14 : 12
    }

    private var verticalPadding: CGFloat {
        if isLarge { return 14 }
        return isSelected ? 9 : 8
    }

    private var iconSize: CGFloat {
        if isLarge { return 16 }
        return isSelected ? 13 : 12
    }

    private var textFont: Font {
        if isLarge { return .system(size: 16, weight: .bold) }
        return isSelected ? .system(size: 14, weight: .bold) : .system(size: 13, weight: .medium)
    }

    private var titleMaxWidth: CGFloat {
        isLarge ? 260 : 168
    }

    private var tint: Color {
        if isDefault && style == .resume {
            return Color(red: 0.96, green: 0.73, blue: 0.28)
        }

        switch style {
        case .resume:   return Color(UIColor.tertiaryLabel)
        case .attached: return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .add:      return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .deleted:  return Color(UIColor.secondaryLabel)
        }
    }

    private var pillOpacity: Double {
        if style == .deleted { return 0.72 }
        if style == .resume && !isDefault && !isSelected { return 0.65 }
        return 1
    }

    private var iconName: String {
        if isDefault && (style == .resume || style == .attached) {
            return "star.fill"
        }

        switch style {
        case .resume, .attached: return "doc.text.fill"
        case .add:     return "plus.circle.fill"
        case .deleted: return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        Button {
            guard let action else { return }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: .semibold))
                Text(title)
                    .font(textFont)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: style == .add ? nil : titleMaxWidth, alignment: .leading)
                    .strikethrough(style == .deleted, color: tint)
            }
            .foregroundStyle(isSelected ? .white : tint.opacity(0.88))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isSelected
                                ? [tint, tint.opacity(0.75)]
                                : [tint.opacity(style == .deleted ? 0.12 : 0.18), tint.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(Capsule().strokeBorder(isSelected ? tint.opacity(0.0) : tint.opacity(style == .deleted ? 0.20 : 0.25), lineWidth: 0.8))
            )
            .shadow(color: isSelected && showsGlow ? tint.opacity(0.21) : .clear, radius: 6, y: 2)
            .opacity(pillOpacity)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Color + Icon Extensions

extension ApplicationType {
    var color: Color {
        switch self {
        case .fullTime:   return Color(red: 0.35, green: 0.65, blue: 0.96)
        case .partTime:   return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .internship: return Color(red: 0.93, green: 0.38, blue: 0.44)
        case .contract:   return Color(red: 0.62, green: 0.52, blue: 0.96)
        case .Co_op:      return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .temporary:  return Color(red: 0.96, green: 0.52, blue: 0.62)
        }
    }

    var iconName: String {
        switch self {
        case .fullTime:   return "briefcase.fill"
        case .partTime:   return "clock.fill"
        case .internship: return "graduationcap.fill"
        case .contract:   return "doc.text.fill"
        case .Co_op:      return "building.2.fill"
        case .temporary:  return "timer"
        }
    }
}

extension ApplicationStatus {
    var color: Color {
        switch self {
        case .toApply:   return Color(red: 0.58, green: 0.62, blue: 0.82)
        case .applied:   return Color(red: 0.35, green: 0.65, blue: 0.96)
        case .interview: return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .offer:     return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .rejected:  return Color(red: 0.93, green: 0.38, blue: 0.44)
        }
    }

    var iconName: String {
        switch self {
        case .toApply:   return "plus.circle.fill"
        case .applied:   return "paperplane.fill"
        case .interview: return "person.2.fill"
        case .offer:     return "checkmark.seal.fill"
        case .rejected:  return "xmark.circle.fill"
        }
    }
}

extension ApplicationSeason {
    var color: Color {
        switch self {
        case .spring: return Color(red: 0.96, green: 0.52, blue: 0.62)
        case .summer: return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .fall:   return Color(red: 0.80, green: 0.46, blue: 0.20)
        case .winter: return Color(red: 0.35, green: 0.65, blue: 0.96)
        }
    }

    var iconName: String {
        switch self {
        case .spring: return "leaf.fill"
        case .summer: return "sun.max.fill"
        case .fall:   return "wind"
        case .winter: return "snowflake"
        }
    }
}
