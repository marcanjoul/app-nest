# App Nest

An iOS app for tracking job and internship applications, built with SwiftUI.

---

## Features

**Track applications** — Add jobs manually with company, position, type, status, season, compensation (hourly or salary, with a currency picker), date, notes, and a resume attachment. Edit or delete anytime.

**Share Extension** — Share any job listing URL directly from Safari. App Nest parses the page title to extract the company and position automatically, auto-detects job type and season from title keywords, and lets you set all fields in the popup before saving — no need to open the app after.

**Flexible CSV Import/Export** — Seamlessly migrate your data. Import jobs from any CSV with a smart, flexible mapper that detects various column headers (e.g., "Employer" vs "Company"). Review and edit parsed data in a beautiful preview sheet before finalizing. Export your entire list or specific search cycles to standard CSV.

**Bulk Management** — Enter **Edit Mode** to select multiple applications. Perform mass actions like deletion or moving jobs between cycles with a single tap.

**Swipe Gestures** — Swipe right on any card to advance its status through the pipeline. Swipe left to delete with a 4-second undo toast.

**Job Search Cycles** — Organize your applications into distinct periods (e.g., "Summer 2026", "Full-time 2027"). Create, rename, and manage cycles directly in the app.

**Parse emails with on-device AI** — Paste a job confirmation email and AppNest extracts the company name, position, status, and date automatically using Apple's NaturalLanguage framework.

**Company logos** — AppNest automatically fetches company logos as you type or import. Logos are cached and saved to your database for a rich, visual experience. Supports manual image uploads too.

**Search, sort, and filter** — Find applications instantly by company or position. Sort by date or company name. Filter by status with high-end glassmorphic chips.

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
