import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Universal Selectable Pill

/// Selectable form option with a stable touch target.
struct SelectablePill<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let option: T
    let isSelected: Bool
    let color: Color
    var icon: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button {
            AppHaptics.shared.light()
            onTap()
        } label: {
            HStack(spacing: isSelected ? 6 : 5) {
                if let icon {
                    AppIcon(icon)
                        .appFont(isSelected ? 13 : 12, weight: .bold)
                        .foregroundStyle(isSelected ? .white : color)
                }
                Text(option.rawValue)
                    .appFont(isSelected ? 14 : 13, weight: isSelected ? .bold : .semibold)
                    .foregroundStyle(isSelected ? .white : color.opacity(0.88))
            }
            .padding(.horizontal, isSelected ? 14 : 12)
            .padding(.vertical, isSelected ? 9 : 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
                    .overlay(
                        Capsule().strokeBorder(
                            isSelected ? Color.clear : color.opacity(0.28),
                            lineWidth: isSelected ? 0 : 0.8
                        )
                    )
            )
            .frame(minHeight: 44)
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.appCrisp, value: isSelected)
        .accessibilityLabel(option.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
    var preview: (() -> AnyView)? = nil

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
            AppHaptics.shared.light()
            action()
        } label: {
            HStack(spacing: 6) {
                AppIcon(iconName)
                    .appFont(iconSize, weight: .semibold)
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
                    .fill(isSelected ? tint : tint.opacity(style == .deleted ? 0.12 : 0.14))
                    .overlay(Capsule().strokeBorder(isSelected ? tint.opacity(0.0) : tint.opacity(style == .deleted ? 0.20 : 0.25), lineWidth: 0.8))
            )
            .opacity(pillOpacity)
        }
        .buttonStyle(PressScaleButtonStyle())
        .allowsHitTesting(action != nil)
        .animation(.appCrisp, value: isSelected)
        .if(preview != nil) { view in
            view.contextMenu {
                if let action {
                    Button(action: action) {
                        AppLabel("Open Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                }
            } preview: {
                if let preview {
                    preview()
                }
            }
        }
    }
}

#if canImport(UIKit)
#endif

// MARK: - Status Pill

/// Status badge with a distinct icon and color.
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
            AppIcon(style.iconName)
                .appFont(12, weight: .semibold)
            Text(displayText)
                .appFont(13, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(style.tintColor)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(style.fillColor), in: .capsule)
    }
}

// MARK: - Type Tag

/// Compact job type label.
struct DarkTypeTag: View {
    let text: String
    var icon: String? = nil
    var color: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                AppIcon(icon)
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
        .glassEffect(.regular.tint(color.opacity(0.13)), in: .capsule)
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
                AppIcon(style.iconName)
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
            .glassEffect(.regular.tint(isSelected ? style.tintColor : style.fillColor).interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .animation(.appCrisp, value: isSelected)
    }
}

// MARK: - Color + Icon Extensions

extension ApplicationType {
    var color: Color {
        switch self {
        case .fullTime:   return Color(red: 0.25, green: 0.48, blue: 0.88) // indigo — distinct from applied's sky blue
        case .partTime:   return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .internship: return Color(red: 0.18, green: 0.68, blue: 0.74) // teal — neutral, removes red/rejection read
        case .contract:   return Color(red: 0.62, green: 0.52, blue: 0.96)
        case .Co_op:      return Color(red: 0.25, green: 0.75, blue: 0.62) // mint — distinct from offer's bright green
        case .temporary:  return Color(red: 0.94, green: 0.48, blue: 0.28) // coral — distinct from spring's pink
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
    // ponytail: single status palette — Theme.statusStyle derives from this.
    var color: Color {
        switch self {
        case .toApply:    return Theme.statusTint(red: 0.58, green: 0.62, blue: 0.82)
        case .applied:    return Theme.statusTint(red: 0.30, green: 0.60, blue: 0.94)
        case .interview:  return Theme.statusTint(red: 0.96, green: 0.65, blue: 0.14)
        case .offer:      return Theme.statusTint(red: 0.30, green: 0.80, blue: 0.45)
        case .rejected:   return Theme.statusTint(red: 0.93, green: 0.33, blue: 0.40)
        case .ghosted:    return Theme.statusTint(red: 0.52, green: 0.52, blue: 0.54)
        case .jobRemoved: return Theme.statusTint(red: 0.88, green: 0.52, blue: 0.20)
        }
    }

    var iconName: String {
        switch self {
        case .toApply:    return "plus.circle.fill"
        case .applied:    return "paperplane.fill"
        case .interview:  return "person.2.fill"
        case .offer:      return "checkmark.seal.fill"
        case .rejected:   return "xmark.circle.fill"
        case .ghosted:    return "moon.zzz.fill"
        case .jobRemoved: return "minus.circle.fill"
        }
    }
}

extension WorkMode {
    var color: Color {
        switch self {
        case .remote: return Color(red: 0.52, green: 0.62, blue: 0.92) // cornflower — distinct from applied's blue
        case .hybrid: return Color(red: 0.62, green: 0.52, blue: 0.96)
        case .onSite: return Color(red: 0.42, green: 0.66, blue: 0.52) // sage — distinct from offer's bright green
        }
    }

    var iconName: String {
        switch self {
        case .remote: return "wifi"
        case .hybrid: return "arrow.left.arrow.right"
        case .onSite: return "building.2.fill"
        }
    }
}

extension ApplicationSeason {
    var color: Color {
        switch self {
        case .spring: return Color(red: 0.96, green: 0.52, blue: 0.62)
        case .summer: return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .fall:   return Color(red: 0.80, green: 0.46, blue: 0.20)
        case .winter: return Color(red: 0.55, green: 0.80, blue: 0.96) // ice blue — distinct from applied's saturated blue
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
