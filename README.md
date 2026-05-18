# App Nest

An iOS app for tracking job and internship applications, built with SwiftUI.

---

## Features

**Track applications** — Add jobs manually with company, position, type, status, season, compensation (hourly or salary, with a currency picker), date, notes, and a resume attachment. Edit or delete anytime.

**Flexible CSV Import/Export** — Seamlessly migrate your data. Import jobs from any CSV with a smart, flexible mapper that detects various column headers (e.g., "Employer" vs "Company"). Review and edit parsed data in a beautiful preview sheet before finalizing. Export your entire list or specific search cycles to standard CSV.

**Bulk Management** — Enter **Edit Mode** to select multiple applications. Perform mass actions like deletion or moving jobs between cycles with a single tap.

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
| Design System | Custom "Stitch" inspired Dark Theme + Emil-motion principles |

---

## Architecture

AppNest uses **SwiftData** as its persistence layer. Views query the database directly using `@Query`, eliminating the need for boilerplate ViewModel classes. Data updates are reactive and instantaneous across all views.

```
AppNest/
├── Core/                 # Entry point, AppState, and API Config
├── DesignSystem/         # Theme (Glassmorphism), Motion, and Haptics
├── Models/               # SwiftData @Models (JobApplication, JobCycle, Resume)
├── Views/
│   ├── Screens/          # Main application screens (Application, Profile, etc.)
│   └── Components/       # Atomic UI elements (Pills, Cards, Modular Form Sections)
└── Assets.xcassets       # Static assets, branding, and color tokens
```

---

## Getting Started

### Requirements

- macOS with Xcode installed (iOS 26.0+ SDK)
- A Logo.dev account for automatic company logo fetching

### Setup

1. Clone the repo
2. Create `AppNest/Core/APIKeys.swift` (see `APIKeys.example.swift`)
3. Open `AppNest.xcodeproj` and run on an iOS 26+ simulator

---

## Recent Updates

- **Polished UX**: Integrated `emil-design-eng` motion principles for smooth, purposeful animations.
- **Enhanced Haptics**: Added tactile feedback for search, sorting, and data management actions.
- **Robust Importer**: Built a high-end CSV import flow with a two-column stat block and filtered review modes.
- **Cycle Control**: Added long-press context menus to rename or delete job search cycles safely.

---

## License

MIT License — Copyright (c) 2026 Mark Anjoul.
