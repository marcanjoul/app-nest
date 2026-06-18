//
//  Theme.swift
//  AppNest
//
//  Created by Mark Anjoul on 3/18/26.
//

import SwiftUI

enum Theme {

    // MARK: - Accent

    static let accent      = Color(red: 0.39, green: 0.60, blue: 0.13)
    static let accentLight = Color(red: 0.92, green: 0.95, blue: 0.87)
    static let accentDark  = Color(red: 0.15, green: 0.31, blue: 0.04)

    // MARK: - Destructive

    static let destructive = Color(red: 0.93, green: 0.33, blue: 0.40)

    // MARK: - Background

    static let background = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.03, green: 0.06, blue: 0.03, alpha: 1.0)
            : UIColor.systemBackground
    })

    // MARK: - Card

    static let cardRadius: CGFloat = 20

    static let cardFill: Color = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 0.85)
            : UIColor.secondarySystemGroupedBackground
    })

    static let cardBorder: Color = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.04)
    })

    // MARK: - Text

    static let textPrimary   = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary  = Color(UIColor.tertiaryLabel)

    // MARK: - Status Pill Styles

    struct StatusStyle {
        let tintColor:   Color
        let fillColor:   Color
        let borderColor: Color
        let iconName:    String
    }

    static func statusStyle(for status: ApplicationStatus) -> StatusStyle {
        switch status {
        case .toApply:
            let c = Color(red: 0.58, green: 0.62, blue: 0.82)
            return StatusStyle(tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18), iconName: "plus.circle.fill")
        case .applied:
            let c = Color(red: 0.30, green: 0.60, blue: 0.94)
            return StatusStyle(tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18), iconName: "paperplane.fill")
        case .interview:
            let c = Color(red: 0.96, green: 0.65, blue: 0.14)
            return StatusStyle(tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18), iconName: "person.2.fill")
        case .offer:
            let c = Color(red: 0.30, green: 0.80, blue: 0.45)
            return StatusStyle(tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18), iconName: "checkmark.seal.fill")
        case .rejected:
            let c = Color(red: 0.93, green: 0.33, blue: 0.40)
            return StatusStyle(tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18), iconName: "xmark.circle.fill")
        case .ghosted:
            let c = Color(red: 0.52, green: 0.52, blue: 0.54)
            return StatusStyle(tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18), iconName: "moon.zzz.fill")
        case .jobRemoved:
            let c = Color(red: 0.88, green: 0.52, blue: 0.20)
            return StatusStyle(tintColor: c, fillColor: c.opacity(0.12), borderColor: c.opacity(0.18), iconName: "minus.circle.fill")
        }
    }


    // MARK: - Type Tag

    static let typeTagFill:   Color    = Color.primary.opacity(0.05)
    static let typeTagRadius: CGFloat  = 10

    // MARK: - Stat Chip

    static let statChipFill:   Color   = Color(UIColor.secondarySystemGroupedBackground)
    static let statChipRadius: CGFloat = 18

    // MARK: - Avatar Gradients

    static let avatarColors: [Color] = [
        Color(red: 0.36, green: 0.66, blue: 0.96),
        Color(red: 0.96, green: 0.73, blue: 0.28),
        Color(red: 0.30, green: 0.80, blue: 0.45),
        Color(red: 0.93, green: 0.38, blue: 0.44),
        Color(red: 0.62, green: 0.52, blue: 0.96),
        Color(red: 0.96, green: 0.52, blue: 0.62),
    ]

    static func avatarFill(for name: String) -> Color {
        let hash = stableHash(name)
        return avatarColors[hash % avatarColors.count]
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

    static let sectionLabelSize:    CGFloat = 11
    static let sectionLabelSpacing: CGFloat = 0.8
}
