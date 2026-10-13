import SwiftUI

/// Pastel placeholder for anything without an image: the profile photo, and company logos
/// that don't exist or haven't loaded yet. Fills its frame — the caller sets size and clip shape.
///
/// While `name` is changing (someone typing a company name) it shows the empty placeholder,
/// and the initial only appears once the name has been still for `settleDelay`.
struct InitialAvatar: View {
    let name: String
    let fontSize: CGFloat
    /// Shown when there's no name to take an initial from, and while the name is being typed.
    var emptyIcon: String = "building.2"

    private static let settleDelay: Duration = .milliseconds(600)

    /// The last name that stopped changing. Starts equal to `name`, so a static avatar
    /// (a job card) shows its initial immediately.
    @State private var settledName: String

    init(name: String, fontSize: CGFloat, emptyIcon: String = "building.2") {
        self.name = name
        self.fontSize = fontSize
        self.emptyIcon = emptyIcon
        _settledName = State(initialValue: name)
    }

    private var initial: String? {
        guard name == settledName,
              let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first
        else { return nil }
        return String(first).uppercased()
    }

    var body: some View {
        // Hashed off the initial, not the whole name, so the colour holds steady as a name is
        // typed or edited — every "S…" company shares a colour.
        let colors = Theme.avatarColor(for: initial ?? "AppNest")
        ZStack {
            colors.background
            if let initial {
                Text(initial)
                    .appFont(fontSize, weight: .bold)
                    .transition(.opacity)
            } else {
                AppIcon(emptyIcon)
                    .appFont(fontSize * 0.95, weight: .bold)
                    .transition(.opacity)
            }
        }
        .foregroundStyle(colors.foreground)
        .animation(.appSmooth, value: initial)
        .task(id: name) {
            try? await Task.sleep(for: Self.settleDelay)
            guard !Task.isCancelled else { return }
            settledName = name
        }
    }
}
