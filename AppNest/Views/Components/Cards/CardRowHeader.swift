import SwiftUI

/// Reusable header row used by expandable and action cards.
/// Renders a tinted icon circle, title, subtitle, and an arbitrary trailing view.
struct CardRowHeader<Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isProminent: Bool = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(isProminent ? 0.18 : 0.15))
                    .frame(width: isProminent ? 56 : 48, height: isProminent ? 56 : 48)
                Image(systemName: icon)
                    .appFont(isProminent ? 24 : 20, weight: .semibold)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(isProminent ? 18 : 17, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .appFont(13, weight: .medium)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            trailing()
        }
        .padding(20)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
