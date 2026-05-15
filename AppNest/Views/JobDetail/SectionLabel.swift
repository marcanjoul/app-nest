import SwiftUI

/// Small uppercase row label with a leading SF Symbol icon used by the
/// `JobDetailView` form sections.
struct SectionLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DarkTheme.textSecondary)
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(DarkTheme.textSecondary)
        }
    }
}
