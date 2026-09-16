import SwiftUI
import CoreText

private struct IconSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 18
}

extension EnvironmentValues {
    var appIconSize: CGFloat {
        get { self[IconSizeKey.self] }
        set { self[IconSizeKey.self] = newValue }
    }
}

/// Bundled Lucide glyphs keep the app's icons consistent without a network dependency.
struct AppIcon: View {
    let name: String
    @Environment(\.appIconSize) private var size

    init(_ name: String) { self.name = name }

    var body: some View {
        Text(Self.glyph(for: name))
            .font(.custom(Self.fontName, fixedSize: size))
            .frame(width: size, height: size)
            .accessibilityLabel(name.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
    }

    private static let fontName: String = {
        guard let url = Bundle.main.url(forResource: "lucide", withExtension: "ttf") else {
            assertionFailure("Missing bundled icon font")
            return "lucide"
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        return descriptors.flatMap { $0.first }.map {
            CTFontCopyPostScriptName(CTFontCreateWithFontDescriptor($0, 20, nil)) as String
        } ?? "lucide"
    }()

    static func image(for name: String) -> Image {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { _ in
            let font = UIFont(name: fontName, size: 22) ?? .systemFont(ofSize: 22)
            let text = NSAttributedString(string: glyph(for: name), attributes: [.font: font, .foregroundColor: UIColor.black])
            let size = text.size()
            text.draw(at: CGPoint(x: (24 - size.width) / 2, y: (24 - size.height) / 2))
        }
        return Image(uiImage: image.withRenderingMode(.alwaysTemplate))
    }

    private static func glyph(for name: String) -> String {
        glyphs[name] ?? glyphs["circle"]!
    }

    private static let glyphs: [String: String] = [
        "building.2": "\u{e28f}",
        "suit.heart.fill": "\u{e0f5}",
        "arrow.clockwise": "\u{e14c}",
        "arrow.clockwise.circle.fill": "\u{e14c}",
        "tray.full.fill": "\u{e045}",
        "briefcase": "\u{e5d9}",
        "briefcase.fill": "\u{e5d9}",
        "envelope.open.fill": "\u{e366}",
        "envelope": "\u{e112}",
        "envelope.fill": "\u{e112}",
        "chart.bar.fill": "\u{e610}",
        "chart.bar.xaxis": "\u{e610}",
        "chart.bar": "\u{e610}",
        "chart.line.uptrend.xyaxis": "\u{e610}",
        "person": "\u{e46c}",
        "person.fill": "\u{e46c}",
        "person.2.fill": "\u{e1a3}",
        "person.wave.2.fill": "\u{e1a3}",
        "checkmark.circle.fill": "\u{e225}",
        "checkmark.seal.fill": "\u{e225}",
        "checkmark.circle": "\u{e225}",
        "checkmark": "\u{e070}",
        "xmark.circle.fill": "\u{e088}",
        "xmark": "\u{e1b1}",
        "plus.circle.fill": "\u{e086}",
        "plus": "\u{e140}",
        "minus.circle.fill": "\u{e083}",
        "minus": "\u{e11f}",
        "arrow.up.right.circle.fill": "\u{e051}",
        "arrow.up.right": "\u{e051}",
        "arrow.down.right.circle": "\u{e049}",
        "arrow.left.arrow.right": "\u{e249}",
        "arrow.up": "\u{e04e}",
        "arrow.down": "\u{e046}",
        "chevron.left": "\u{e072}",
        "chevron.right": "\u{e073}",
        "chevron.down": "\u{e071}",
        "chevron.up": "\u{e074}",
        "doc.text": "\u{e0d0}",
        "doc.text.fill": "\u{e0d0}",
        "doc.richtext": "\u{e0d0}",
        "doc.richtext.fill": "\u{e0d0}",
        "doc.fill": "\u{e0d0}",
        "doc": "\u{e0d0}",
        "doc.text.magnifyingglass": "\u{e0cf}",
        "tablecells": "\u{e326}",
        "tablecells.fill": "\u{e326}",
        "folder": "\u{e0dc}",
        "folder.fill": "\u{e0dc}",
        "folder.badge.questionmark": "\u{e0dc}",
        "tray.fill": "\u{e045}",
        "tray.2.fill": "\u{e045}",
        "tray.full": "\u{e045}",
        "tray": "\u{e045}",
        "tray.and.arrow.down": "\u{e045}",
        "square.and.arrow.down.fill": "\u{e0b6}",
        "square.and.arrow.down": "\u{e0b6}",
        "square.and.arrow.up": "\u{e19d}",
        "square.and.pencil": "\u{e175}",
        "pencil": "\u{e1f8}",
        "link": "\u{e107}",
        "trash": "\u{e18c}",
        "trash.fill": "\u{e18c}",
        "magnifyingglass": "\u{e154}",
        "line.3.horizontal.decrease.circle": "\u{e299}",
        "line.3.horizontal.decrease": "\u{e299}",
        "slider.horizontal.3": "\u{e299}",
        "calendar": "\u{e067}",
        "calendar.day.timeline.left": "\u{e067}",
        "calendar.badge.clock": "\u{e067}",
        "calendar.badge.plus": "\u{e067}",
        "clock.fill": "\u{e08b}",
        "clock": "\u{e08b}",
        "timer": "\u{e1df}",
        "camera.fill": "\u{e068}",
        "camera": "\u{e068}",
        "bell.badge.fill": "\u{e05d}",
        "bell.fill": "\u{e05d}",
        "exclamationmark.triangle.fill": "\u{e192}",
        "exclamationmark.circle.fill": "\u{e192}",
        "info.circle": "\u{e0fe}",
        "dollarsign.circle": "\u{e481}",
        "graduationcap.fill": "\u{e233}",
        "building.2.fill": "\u{e28f}",
        "moon.zzz.fill": "\u{e121}",
        "paperplane.fill": "\u{e155}",
        "list.bullet": "\u{e10b}",
        "list.bullet.rectangle": "\u{e10b}",
        "rectangle.and.hand.point.up.left.fill": "\u{e10b}",
        "sun.max.fill": "\u{e17b}",
        "sun.snow.fill": "\u{e17b}",
        "snowflake": "\u{e168}",
        "wind": "\u{e1af}",
        "leaf.fill": "\u{e2dd}",
        "mappin.circle.fill": "\u{e114}",
        "mappin.and.ellipse": "\u{e114}",
        "mappin": "\u{e114}",
        "wifi": "\u{e1ad}",
        "mic.fill": "\u{e11b}",
        "gearshape.fill": "\u{e157}",
        "waveform": "\u{e55e}",
        "star": "\u{e179}",
        "star.fill": "\u{e179}",
        "sparkles": "\u{e416}",
        "sparkle": "\u{e416}",
        "circle": "\u{e07a}",
        "circle.fill": "\u{e07a}",
        "arrow.up.left.and.arrow.down.right": "\u{e116}",
        "doc.on.doc": "\u{e0a2}",
        "doc.on.doc.fill": "\u{e0a2}",
        "ellipsis": "\u{e0ba}",
        "ellipsis.circle": "\u{e0ba}",
        "heart.fill": "\u{e0f5}",
        "arrow.up.forward.square": "\u{e0bd}",
        "arrow.left": "\u{e04c}",
        "arrow.uturn.backward": "\u{e14b}"
    ]
}

struct AppLabel: View {
    let title: String
    let icon: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.icon = systemImage
    }

    var body: some View {
        Label { Text(title) } icon: { AppIcon.image(for: icon) }
    }
}
