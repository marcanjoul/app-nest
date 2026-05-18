# App Nest

A personal iOS job application tracker built with SwiftUI and SwiftData. Designed for students and early-career professionals who want a calm, fast, private record of where their job search stands — without spreadsheet chaos or bloated job-board UIs.

> Built and maintained by [Mark Anjoul](https://github.com/marcanjoul).

---

## What It Does

You share a job listing from your browser, App Nest parses the company and title automatically, you pick a status and job type in the popup, and it's saved. When you land an interview, swipe right on the card to advance the status. When you get rejected, swipe left to delete. That's the core loop.

Beyond that: CSV import/export, on-device email parsing, company logos, compensation tracking, job search cycles, and a full detail view with notes and resume attachment.

---

## Features

### Share Extension
Share any job listing URL directly from Safari. App Nest parses the page title to extract the company name and position automatically. The popup lets you set job type, status, season, and notes before saving — no need to re-open the app after.

- Handles LinkedIn, Greenhouse, Lever, Indeed, Adzuna, Workday, Handshake, ZipRecruiter, and more
- Auto-detects job type from the title (e.g. "Summer Internship" → Internship + Summer)
- Falls back to HTML fetch for open job boards; gracefully degrades to manual entry for auth-walled sites

### Application Tracking
Each job stores:
- Company name + logo
- Position title
- Job type (Full Time, Part Time, Contract, Internship, Co-op, Temporary)
- Status (To Apply → Applied → Interview → Offer / Rejected)
- Season (Winter, Spring, Summer, Fall)
- Date applied
- Job URL
- Notes, company research, and interview notes (separate fields)
- Compensation (hourly or salary, with currency picker and period)
- Resume attachment (file reference, not a copy)

### Swipe Gestures
- **Swipe right** on any card to advance to the next status in the pipeline (To Apply → Applied → Interview → Offer). Multi-stage: swipe further to jump ahead.
- **Swipe left** to delete with a 4-second undo toast.

### Job Search Cycles
Organize applications into named periods ("Summer 2025", "Full-Time 2026"). Filter your entire list to a single cycle with one tap. Cycles are optional — all applications are visible in the default "All Applications" view.

### CSV Import / Export
- Import from any CSV: a flexible mapper auto-detects column headers (e.g. "Employer" and "Company" both work). Preview and edit all rows in a full-screen sheet before committing.
- Export your current list or cycle to a standard CSV for backup or migration.

### Email Parsing
Paste a job confirmation email and App Nest extracts the company name, position, and status using Apple's on-device NaturalLanguage framework. No data leaves the device.

### Company Logos
Logos are fetched automatically from [Logo.dev](https://logo.dev) as you type or import. Fetched images are stored in SwiftData and persist across sessions. Custom logos can be uploaded from your photo library.

### Search, Sort, Filter
- Full-text search across company and position
- Sort by date (newest/oldest) or company name (A–Z / Z–A)
- Filter by status using animated chip pills — tap to select, tap again to clear
- Counts on each chip update live as you search

### Bulk Actions
Enter Edit Mode to select multiple applications, then delete or move them to a cycle in one action.

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| UI | SwiftUI | Declarative, fast iteration, tight SwiftData integration |
| Persistence | SwiftData (SQLite) | First-party, reactive, zero boilerplate for `@Query` |
| NLP | Apple NaturalLanguage (`NLTagger`) | On-device, private, no API key required |
| Logo API | Logo.dev | Clean REST API, reliable domain-to-logo lookup |
| Architecture | `@Query`-driven MVVM | Views observe the DB directly; no intermediate ViewModel layer needed |
| Design | Custom dark theme, Emil-motion principles | Glassmorphism cards, spring animations, haptic feedback |

**iOS target:** iOS 17+  
**Language:** Swift 5.9  
**Xcode:** 16+

---

## Architecture

```
app-nest/
├── AppNest/
│   ├── Core/
│   │   ├── AppNestApp.swift        # @main entry point, scene lifecycle, share import handling
│   │   ├── AppState.swift          # Global observable state (selected cycle, pending import)
│   │   └── APIKeys.swift           # Logo.dev credentials (git-ignored)
│   ├── Models/
│   │   ├── JobApplication.swift    # SwiftData @Model — main entity
│   │   ├── JobCycle.swift          # SwiftData @Model — grouping entity
│   │   ├── PendingJobImport.swift  # Codable DTO: share extension → main app via App Group
│   │   ├── LogoFetcher.swift       # Logo.dev search + image download
│   │   ├── EmailParser.swift       # NaturalLanguage-based email extraction
│   │   └── CSVImporter.swift       # Flexible CSV parser with header normalization
│   ├── Views/
│   │   ├── Screens/
│   │   │   ├── ApplicationView.swift   # Main job list — search, filter, swipe, bulk actions
│   │   │   ├── JobDetailView.swift     # Full editing form for a single application
│   │   │   ├── ProfileView.swift       # Resume management and app settings
│   │   │   └── Import/                 # CSV preview, row editor, import support
│   │   └── Components/
│   │       ├── Cards/                  # DarkJobCardView, swipe row
│   │       ├── JobDetail/              # Modular form sections (info, compensation, notes…)
│   │       └── Pills/                  # Status chips, selectable pills, type badges
│   └── Design/
│       ├── Theme/DarkTheme.swift       # Color tokens, card styles, status colors
│       ├── Motion/Animations.swift     # Named spring presets
│       └── Haptics/Haptics.swift       # Centralized haptic feedback
└── AppNestShare/
    └── ShareViewController.swift   # Self-contained share extension (UIKit host + SwiftUI popup)
```

### Data Flow — Share Extension Import

```
Safari (user taps Share)
  └─▶ ShareViewController
        ├─ Parses URL + page title from NSExtensionItem
        ├─ Fetches og:title / HTML title via URLSession (fallback)
        ├─ Runs parseJobInfo() → extracts company + position
        ├─ Detects job type and season from title keywords
        └─ User fills in popup → saves SharePendingImport
             └─▶ UserDefaults (App Group)
                  └─▶ AppNestApp (scenePhase .active)
                        └─▶ ApplicationView.onChange → inserts JobApplication into SwiftData
```

### Why No ViewModel Classes?

SwiftData's `@Query` macro makes view-models redundant for read-heavy flows. Views subscribe directly to the persistent store and re-render when data changes. The only shared state (current cycle, pending import) lives in `AppState`, an `@Observable` class injected via `.environment`.

---

## Getting Started

### Requirements

- Xcode 16+ on macOS
- iOS 17+ simulator or device
- A free [Logo.dev](https://logo.dev) account for logo fetching (optional — the app works without it, logos just won't auto-load)

### Setup

```bash
git clone https://github.com/marcanjoul/app-nest.git
cd app-nest
```

1. Copy the API keys template:
   ```bash
   cp AppNest/Core/APIKeys.example.swift AppNest/Core/APIKeys.swift
   ```
2. Fill in your Logo.dev keys in `APIKeys.swift`
3. Open `AppNest.xcodeproj` in Xcode
4. Select a simulator (iOS 17+) and hit Run

The share extension (`AppNestShare` target) is bundled with the main app. It uses an App Group (`group.com.example.mark.appnest`) to pass data — update this identifier in both targets' entitlements if you change the bundle ID.

---

## Design Philosophy

App Nest is designed around one principle: **the app should reduce stress, not add it.** Every interaction is optimized for speed and clarity.

- Cards show exactly what matters at a glance — company, title, status badge, date
- Status advancement is a gesture, not a form
- The share extension imports a job in under five seconds
- Nothing is hidden behind a menu that could reasonably be a swipe

The visual language is intentionally dark and calm — glassmorphic cards, muted status colors, spring-based animations that feel physical rather than decorative.

---

## License

MIT License — Copyright (c) 2026 Mark Anjoul.
