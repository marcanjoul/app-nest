# App Nest

An iOS app for tracking job and internship applications, built with SwiftUI.

---

## Screenshots

> _Add screenshots or GIFs here_

---

## Features

### Tracking
| | |
|---|---|
| **Applications** | Company, position, type, status, season, compensation, notes, resume attachment |
| **Swipe to advance** | Swipe right to move a card through the pipeline; swipe left to delete with undo |
| **Cycles** | Group applications by search period (e.g. "Summer 2026", "Full-Time 2027") |
| **Bulk actions** | Edit Mode for mass delete or move-to-cycle |

### Import
| | |
|---|---|
| **Share Extension** | Share any job URL from Safari — auto-parses company, position, job type, and season |
| **CSV Import** | Flexible mapper handles any column naming; preview and edit before committing |
| **Email parsing** | Paste a confirmation email — on-device AI extracts company, position, and status |

### Discovery
| | |
|---|---|
| **Search** | Full-text across company and position, live as you type |
| **Filter & sort** | Filter by status chips; sort by date or company name |
| **Company logos** | Auto-fetched from Logo.dev, cached to the database, or upload your own |
| **CSV Export** | Export your list or active cycle to a standard CSV |

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData (SQLite) |
| NLP / Parsing | Apple NaturalLanguage (NLTagger) + Regex + NSDataDetector |
| Logo Lookup | Logo.dev API |
| Architecture | Modern SwiftData MVVM (Direct @Query) |
| Design System | Custom Dark Theme + Emil-motion principles |

---

## Architecture

AppNest uses **SwiftData** as its persistence layer. Views query the database directly using `@Query`, eliminating the need for boilerplate ViewModel classes. Data updates are reactive and instantaneous across all views.

```
AppNest/
├── Core/                 # Entry point, AppState, and API Config
├── Design System/        # Theme (Glassmorphism), Motion, and Haptics
├── Models/               # SwiftData @Models (JobApplication, JobCycle, Resume)
├── Views/
│   ├── Screens/          # Main application screens (Application, Profile, etc.)
│   └── Components/       # Atomic UI elements (Pills, Cards, Modular Form Sections)
└── Assets.xcassets       # Static assets, branding, and color tokens

AppNestShare/
└── ShareViewController.swift  # Self-contained share extension (UIKit host + SwiftUI popup)
```
---

## Getting Started

### Requirements

- macOS with Xcode 16+ installed (iOS 17.0+ SDK)
- A [Logo.dev](https://logo.dev) account for automatic company logo fetching (free tier works)

### Setup

1. Clone the repo
2. Create `AppNest/Core/APIKeys.swift` from the example file:
   ```swift
   enum APIKeys {
       static let logoDevPublicKey  = "pk_YOUR_PUBLISHABLE_KEY_HERE"
       static let logoDevSecretKey  = "sk_YOUR_SECRET_KEY_HERE"
   }
   ```
   Logo.dev uses two separate keys — both are in your Logo.dev dashboard. `APIKeys.swift` is gitignored and should never be committed.
3. Open `AppNest.xcodeproj` and run on an iOS 17+ simulator

---

## License

MIT License — Copyright (c) 2026 Mark Anjoul.
