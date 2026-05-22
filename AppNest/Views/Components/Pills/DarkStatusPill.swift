import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Status Pill

/// Glassmorphic status pill with SF Symbol icon and colored gradient capsule.
struct DarkStatusPill: View {
    let status: ApplicationStatus

    private var style: Theme.StatusStyle { Theme.statusStyle(for: status) }

    private var displayText: String {
        switch status {
        case .interview: return "Interview"
        default:         return status.rawValue
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: style.iconName)
                .appFont(12, weight: .semibold)
            Text(displayText)
                .appFont(13, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(style.tintColor)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(style.fillColor)
                .overlay(Capsule().strokeBorder(style.borderColor, lineWidth: 0.8))
        )
    }
}

// MARK: - Type Tag

/// Subtle glass capsule tag for displaying job type on cards.
struct DarkTypeTag: View {
    let text: String
    var icon: String? = nil
    var color: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .appFont(11, weight: .bold)
            }
            Text(text)
                .appFont(12, weight: .bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(color.opacity(0.13))
                .overlay(Capsule().strokeBorder(color.opacity(0.24), lineWidth: 0.8))
        )
    }
}

// MARK: - Stat Pill

/// Tappable status-tinted pill that shows a count and acts as a filter toggle.
struct StatChip: View {
    let status: ApplicationStatus
    let number: Int
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    private var style: Theme.StatusStyle { Theme.statusStyle(for: status) }

    private var label: String {
        switch status {
        case .toApply:    return "To Apply"
        case .applied:    return "Applied"
        case .interview:  return "Interview"
        case .offer:      return "Offers"
        case .rejected:   return "Rejected"
        case .ghosted:    return "Ghosted"
        case .jobRemoved: return "Removed"
        }
    }

    var body: some View {
        Button {
            AppHaptics.shared.light()
            action?()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: style.iconName)
                    .appFont(10, weight: .bold)
                    .foregroundStyle(isSelected ? Color.white : style.tintColor)

                Text("\(number)")
                    .appFont(20, weight: .bold)
                    .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.appCrisp, value: number)

                Text(label)
                    .appFont(11, weight: .semibold)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.88) : Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(style.tintColor) : AnyShapeStyle(style.fillColor))
                    .overlay(
                        Capsule().strokeBorder(
                            isSelected ? Color.clear : style.borderColor,
                            lineWidth: isSelected ? 0 : 0.8
                        )
                    )
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.appCrisp, value: isSelected)
    }
}
