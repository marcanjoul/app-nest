import SwiftUI

// MARK: - Display-only Status Pill (used on light-mode job cards)

struct StatusPill: View {
    let text: String
    let background: Color
    let foreground: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(background))
            .foregroundStyle(foreground)
    }
}
