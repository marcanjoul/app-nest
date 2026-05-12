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

    var body: some View {
        HStack(spacing: isSelected ? 6 : 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: isSelected ? 13 : 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : color)
            }
            Text(option.rawValue)
                .font(isSelected ? .system(size: 14, weight: .bold) : .system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : color.opacity(0.85))
        }
        .padding(.horizontal, isSelected ? 14 : 12)
        .padding(.vertical, isSelected ? 9 : 8)
        .background(
            Capsule()
                .fill(isSelected
                      ? LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                      : LinearGradient(colors: [color.opacity(0.18), color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? color.opacity(0.0) : color.opacity(0.25), lineWidth: 0.8)
                )
        )
        .shadow(color: isSelected ? color.opacity(0.35) : .clear, radius: 6, y: 2)
        .onTapGesture {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onTap()
        }
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
