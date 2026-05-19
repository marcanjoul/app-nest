import SwiftUI

/// Small uppercase row label with a leading SF Symbol icon used by the
/// `JobDetailView` form sections.
struct SectionLabel: View {
    let icon: String
    let title: String
    var isRequired: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: Theme.sectionLabelSize - 1, weight: .black))
                .foregroundStyle(Color.accentColor.opacity(0.8))
            
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: Theme.sectionLabelSize, weight: .bold))
                    .tracking(Theme.sectionLabelSpacing)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
                
                if isRequired {
                    Text("*")
                        .font(.system(size: Theme.sectionLabelSize, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel("Required")
                }
            }
        }
    }
}
