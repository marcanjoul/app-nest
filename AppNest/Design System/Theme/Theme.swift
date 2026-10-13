//
//  Theme.swift
//  AppNest
//
//  Created by Mark Anjoul on 3/18/26.
//

import SwiftUI

enum Theme {

    // MARK: - Accent

    static let accent      = Color.accentColor

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



    // MARK: - Section Labels

    static let sectionLabelSize:    CGFloat = 13
    static let sectionLabelSpacing: CGFloat = 0
}
