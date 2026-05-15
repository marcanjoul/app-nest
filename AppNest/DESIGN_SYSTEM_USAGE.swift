//
//  DESIGN_SYSTEM_USAGE.swift
//  AppNest
//
//  Quick reference guide for using the dark theme design system
//

/*

# AppNest Dark Theme Design System Usage

## Color Usage

### Backgrounds
```swift
// Main app background
DarkTheme.background  // #0a0a0f

// Card fill and border
.background(
    RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
        .fill(DarkTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                .strokeBorder(DarkTheme.cardBorder, lineWidth: 0.5)
        )
)
```

### Text Colors
```swift
// Primary text (white)
.foregroundStyle(DarkTheme.textPrimary)

// Secondary text (rgba(255,255,255,0.4))
.foregroundStyle(DarkTheme.textSecondary)

// Tertiary text (rgba(255,255,255,0.25))
.foregroundStyle(DarkTheme.textTertiary)
```

## Components

### Status Pill with Dot
```swift
DarkStatusPill(status: .applied)   // Blue
DarkStatusPill(status: .interview) // Amber, shows "Interviewing"
DarkStatusPill(status: .offer)     // Green
DarkStatusPill(status: .rejected)  // Red
```

### Type Tag
```swift
DarkTypeTag(text: "Internship")
DarkTypeTag(text: "Full-time")
```

### Stat Chip
```swift
StatChip(number: 12, label: "Applied")
```

### Company Avatar with Gradient Fallback
```swift
Text("G")
    .font(.system(size: 22, weight: .bold))
    .foregroundStyle(.white)
    .frame(width: 56, height: 56)
    .background(DarkTheme.avatarGradient(for: "Google"))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
```

## Typography Scale

### Headers
```swift
// Large title
.font(.system(size: 42, weight: .bold))

// Subtitle
.font(.system(size: 18, weight: .medium))

// Section label (uppercase with tracking)
.font(.system(size: 11, weight: .semibold))
.tracking(1.2)
.textCase(.uppercase)
```

### Body Text
```swift
// Card title
.font(.system(size: 16, weight: .semibold))

// Card subtitle
.font(.system(size: 14))

// Pill/tag text
.font(.system(size: 13, weight: .medium))
```

### Stats
```swift
// Large number
.font(.system(size: 28, weight: .bold))

// Stat label
.font(.system(size: 12, weight: .medium))
```

## Corner Radius Values

```swift
DarkTheme.cardRadius      // 20px - main cards
DarkTheme.typeTagRadius   // 8px - type tags
DarkTheme.statChipRadius  // 14px - stat chips

// Pills use Capsule() shape
// Company avatars: 12px
```

## Common Patterns

### Card with dark theme
```swift
VStack {
    // Content
}
.padding(16)
.background(
    RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
        .fill(DarkTheme.cardFill)
        .overlay(
            RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                .strokeBorder(DarkTheme.cardBorder, lineWidth: 0.5)
        )
)
```

### Floating action button
```swift
Button {
    // Action
} label: {
    Image(systemName: "plus")
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(DarkTheme.background)
        .frame(width: 64, height: 64)
        .background(Circle().fill(.white))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
}
```

## Status Colors Reference

Status       | Color   | Hex
-------------|---------|--------
Applied      | Blue    | #5ba8f5
Interviewing | Amber   | #f5b94a
Offer        | Green   | #85c93a
Rejected     | Red     | #f07070

All status styles include:
- Tinted fill (15% opacity)
- Colored border (30% opacity)
- Colored dot indicator
- Pill-shaped capsule

*/
