//
//  Theme.swift
//  AppNest
//
//  Created by Mark Anjoul on 3/18/26.
//


import SwiftUI

/// AppNest's design system — centralized colors and styles.
/// Green primary accent with warm gray neutrals.
enum Theme {
    
    // MARK: - Accent
    static let accent = Color(red: 0.39, green: 0.60, blue: 0.13) // #639922
    static let accentLight = Color(red: 0.92, green: 0.95, blue: 0.87) // #EAF3DE
    static let accentDark = Color(red: 0.15, green: 0.31, blue: 0.04) // #27500A
    
    // MARK: - Status Colors
    
    struct StatusStyle {
        let background: Color
        let foreground: Color
    }
    
    static func style(for status: ApplicationStatus) -> StatusStyle {
        switch status {
        case .applied:
            return StatusStyle(
                background: Color(red: 0.92, green: 0.95, blue: 0.87),
                foreground: Color(red: 0.15, green: 0.31, blue: 0.04)
            )
        case .interview:
            return StatusStyle(
                background: Color(red: 0.90, green: 0.95, blue: 0.98),
                foreground: Color(red: 0.05, green: 0.27, blue: 0.49)
            )
        case .offer:
            return StatusStyle(
                background: Color(red: 0.93, green: 0.93, blue: 1.0),
                foreground: Color(red: 0.24, green: 0.20, blue: 0.54)
            )
        case .rejected:
            return StatusStyle(
                background: Color(red: 0.99, green: 0.92, blue: 0.92),
                foreground: Color(red: 0.47, green: 0.12, blue: 0.12)
            )
        case .toApply:
            return StatusStyle(
                background: Color(red: 0.95, green: 0.94, blue: 0.91),
                foreground: Color(red: 0.37, green: 0.37, blue: 0.35)
            )
        }
    }
    
    // MARK: - Type Colors
    
    static func style(for type: ApplicationType) -> StatusStyle {
        switch type {
        case .internship:
            return StatusStyle(
                background: Color(red: 0.88, green: 0.96, blue: 0.93),
                foreground: Color(red: 0.03, green: 0.31, blue: 0.22)
            )
        case .fullTime:
            return StatusStyle(
                background: Color(red: 0.90, green: 0.95, blue: 0.98),
                foreground: Color(red: 0.05, green: 0.27, blue: 0.49)
            )
        case .partTime:
            return StatusStyle(
                background: Color(red: 0.98, green: 0.93, blue: 0.85),
                foreground: Color(red: 0.52, green: 0.31, blue: 0.04)
            )
        case .contract:
            return StatusStyle(
                background: Color(red: 0.93, green: 0.93, blue: 1.0),
                foreground: Color(red: 0.24, green: 0.20, blue: 0.54)
            )
        case .Co_op:
            return StatusStyle(
                background: Color(red: 0.95, green: 0.94, blue: 0.91),
                foreground: Color(red: 0.37, green: 0.37, blue: 0.35)
            )
        case .temporary:
            return StatusStyle(
                background: Color(red: 0.98, green: 0.92, blue: 0.94),
                foreground: Color(red: 0.45, green: 0.14, blue: 0.24)
            )
        }
    }
    
    // MARK: - Season Colors
    
    static func style(for season: ApplicationSeason) -> StatusStyle {
        switch season {
        case .summer:
            return StatusStyle(
                background: Color(red: 0.98, green: 0.93, blue: 0.85),
                foreground: Color(red: 0.39, green: 0.22, blue: 0.02)
            )
        case .fall:
            return StatusStyle(
                background: Color(red: 0.98, green: 0.93, blue: 0.91),
                foreground: Color(red: 0.44, green: 0.17, blue: 0.08)
            )
        case .winter:
            return StatusStyle(
                background: Color(red: 0.90, green: 0.95, blue: 0.98),
                foreground: Color(red: 0.05, green: 0.27, blue: 0.49)
            )
        case .spring:
            return StatusStyle(
                background: Color(red: 0.98, green: 0.92, blue: 0.94),
                foreground: Color(red: 0.45, green: 0.14, blue: 0.24)
            )
        }
    }
    
    // MARK: - Company Avatar Colors
    
    /// Generates a deterministic color from a company name
    /// so the same company always gets the same avatar color.
    static let avatarPalette: [(background: Color, foreground: Color)] = [
        (Color(red: 0.92, green: 0.95, blue: 0.87), Color(red: 0.23, green: 0.43, blue: 0.07)),
        (Color(red: 0.90, green: 0.95, blue: 0.98), Color(red: 0.09, green: 0.37, blue: 0.65)),
        (Color(red: 0.93, green: 0.93, blue: 1.0), Color(red: 0.33, green: 0.29, blue: 0.72)),
        (Color(red: 0.88, green: 0.96, blue: 0.93), Color(red: 0.06, green: 0.43, blue: 0.34)),
        (Color(red: 0.98, green: 0.93, blue: 0.85), Color(red: 0.52, green: 0.31, blue: 0.04)),
        (Color(red: 0.98, green: 0.92, blue: 0.94), Color(red: 0.45, green: 0.14, blue: 0.24)),
    ]
    
    static func avatarColor(for name: String) -> (background: Color, foreground: Color) {
        let hash = abs(name.hashValue)
        return avatarPalette[hash % avatarPalette.count]
    }
}