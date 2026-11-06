import SwiftUI

private struct IconSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 18
}

extension EnvironmentValues {
    var appIconSize: CGFloat {
        get { self[IconSizeKey.self] }
        set { self[IconSizeKey.self] = newValue }
    }
}

/// SF Symbol sized by the `appIconSize` environment value.
struct AppIcon: View {
    let name: String
    @Environment(\.appIconSize) private var size

    init(_ name: String) { self.name = name }

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size))
            .frame(width: size, height: size)
    }
}

struct AppLabel: View {
    let title: String
    let icon: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.icon = systemImage
    }

    var body: some View {
        Label(title, systemImage: icon)
    }
}
