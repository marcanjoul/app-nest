//
//  Theme.swift
//  AppNest
//
//  Created by Mark Anjoul on 3/18/26.
//

import SwiftUI
import CoreText

enum Theme {

    // MARK: - Accent

    // Named asset, not `Color.accentColor`: that resolved to system blue inside sheets.
    static let accent      = Color("AccentColor")

    // MARK: - Destructive

    static let destructive = Color(red: 0.93, green: 0.33, blue: 0.40)

    // MARK: - Button Green

    /// Every green button — filled CTAs and light-tinted capsule buttons. Taken from the
    /// "Upload Resume" pill. Selection states and icons keep `accent`.
    static let buttonGreen = Color(red: 0.30, green: 0.80, blue: 0.45)

    // MARK: - Background

    static let background = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.075, blue: 0.08, alpha: 1.0)
            : UIColor(red: 0.965, green: 0.97, blue: 0.975, alpha: 1.0)
    })

    // MARK: - Card

    static let cardRadius: CGFloat = 24

    static let cardFill: Color = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.115, green: 0.12, blue: 0.125, alpha: 1.0)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    })

    static let cardBorder: Color = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12)
            : UIColor(red: 0.15, green: 0.17, blue: 0.19, alpha: 0.10)
    })

    // MARK: - Text

    static let textPrimary   = Color(UIColor.label)
    static let textOnPrimary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? .black : .white
    })
    static let textSecondary = Color(UIColor { trait in
        UIColor(white: trait.userInterfaceStyle == .dark ? 0.72 : 0.36, alpha: 1)
    })
    static let textTertiary = Color(UIColor { trait in
        UIColor(white: trait.userInterfaceStyle == .dark ? 0.62 : 0.46, alpha: 1)
    })

    // MARK: - Status Pill Styles

    struct StatusStyle {
        let tintColor:   Color
        let fillColor:   Color
        let iconName:    String
    }

    /// Light mode darkens every channel to 62% so tints keep contrast on white.
    static func statusTint(red: CGFloat, green: CGFloat, blue: CGFloat) -> Color {
        Color(UIColor { trait in
            let factor: CGFloat = trait.userInterfaceStyle == .dark ? 1 : 0.62
            return UIColor(red: red * factor, green: green * factor, blue: blue * factor, alpha: 1)
        })
    }

    static func statusStyle(for status: ApplicationStatus) -> StatusStyle {
        let c = status.color
        return StatusStyle(tintColor: c, fillColor: c.opacity(0.12), iconName: status.iconName)
    }


    // MARK: - Avatar Palette (light-mode)

    static let avatarPalette: [(background: Color, foreground: Color)] = [
        (Color(red: 0.92, green: 0.95, blue: 0.87), Color(red: 0.23, green: 0.43, blue: 0.07)),
        (Color(red: 0.90, green: 0.95, blue: 0.98), Color(red: 0.09, green: 0.37, blue: 0.65)),
        (Color(red: 0.93, green: 0.93, blue: 1.0),  Color(red: 0.33, green: 0.29, blue: 0.72)),
        (Color(red: 0.88, green: 0.96, blue: 0.93), Color(red: 0.06, green: 0.43, blue: 0.34)),
        (Color(red: 0.98, green: 0.93, blue: 0.85), Color(red: 0.52, green: 0.31, blue: 0.04)),
        (Color(red: 0.98, green: 0.92, blue: 0.94), Color(red: 0.45, green: 0.14, blue: 0.24)),
    ]

    static func avatarColor(for name: String) -> (background: Color, foreground: Color) {
        let hash = stableHash(name)
        return avatarPalette[hash % avatarPalette.count]
    }

    /// Stable deterministic hash for strings to keep colors consistent across launches.
    private static func stableHash(_ string: String) -> Int {
        var hash = 5381
        for char in string.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(char.value)
        }
        return abs(hash)
    }



    static let sectionLabelSpacing: CGFloat = 0

    // MARK: - Typography

    /// Display face for titles and headlines: DM Sans, a variable font (OFL 1.1, no Reserved Font
    /// Name; the file ships unmodified beside `DMSans-OFL.txt` in `Design System/Fonts`).
    /// Weight goes on its `wght` axis and optical size on `opsz` (tracks the point size, 9–40),
    /// so every SwiftUI weight works from the one file. nil (failed to load) falls back to SF Pro.
    static func displayFont(size: CGFloat, weight: Font.Weight) -> Font? {
        displayUIFont(size: size, weight: weight).map { Font($0) }
    }

    static func displayUIFont(size: CGFloat, weight: Font.Weight) -> UIFont? {
        guard let displayDescriptor else { return nil }
        let wghtAxis = 0x77676874   // 'wght'
        let opszAxis = 0x6F70737A   // 'opsz'
        let descriptor = displayDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [
                wghtAxis: weight.cssValue,
                opszAxis: min(max(size, 9), 40),
            ],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    private static let displayDescriptor: UIFontDescriptor? = {
        guard let url = Bundle.main.url(forResource: "DMSans-VariableFont_opsz,wght", withExtension: "ttf") else {
            assertionFailure("Missing bundled font DMSans-VariableFont_opsz,wght.ttf")
            return nil
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        guard let ct = (CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first
        else { return nil }
        return UIFontDescriptor(name: CTFontCopyPostScriptName(CTFontCreateWithFontDescriptor(ct, 20, nil)) as String, size: 0)
    }()
}

extension Font.Weight {
    /// The CSS / OpenType `wght` value for this weight.
    var cssValue: CGFloat {
        switch self {
        case .ultraLight: 100
        case .thin:       200
        case .light:      300
        case .medium:     500
        case .semibold:   600
        case .bold:       700
        case .heavy:      800
        case .black:      900
        default:          400
        }
    }
}
