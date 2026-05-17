# App Nest

An iOS app for tracking job and internship applications — built with SwiftUI
---

## Features

**Track applications** — Add jobs manually with company, position, type, status, season, compensation (hourly or salary, with a currency picker), date, notes, and a resume attachment. Edit or delete anytime.

**Parse emails with on-device AI** — Paste a job confirmation email and AppNest extracts the company name, position, status, and date automatically using Apple's NaturalLanguage framework. No API keys, no internet required.

**Search, sort, and filter** — Find applications instantly by company or position. Sort by date or company name. Filter by status with horizontal chips or the toolbar menu.

**Profile and stats** — See your total applications, breakdown by status, and most-applied companies at a glance. Export everything as a CSV.

**Onboarding** — A clean three-screen walkthrough on first launch.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData (SQLite) |
| NLP / Parsing | Apple NaturalLanguage framework (NLTagger) + regex patterns + NSDataDetector |
| Architecture | MVVM-ish — `@Model` + `@Query` replace the traditional ViewModel |
| Minimum Target | iOS 17+ |

---

## Architecture

AppNest uses SwiftData as its persistence layer, which eliminates the need for a traditional ViewModel class. Views query the database directly using `@Query` and mutate data through `@Environment(\.modelContext)`. This keeps the codebase lean — data flows from SQLite → SwiftData → SwiftUI with automatic UI updates on every change.

The email parser uses a hybrid approach: Apple's `NLTagger` handles named entity recognition (extracting company names from natural language), regex patterns match common email templates for position titles, keyword matching detects application status, and `NSDataDetector` extracts dates.

```
AppNest/
├── AppNestApp.swift              # Entry point, ModelContainer + onboarding gate
├── Theme.swift                   # Centralized color system and design tokens
├── DarkTheme.swift               # Dark-mode palette, glass card, ambient background
├── Assets.xcassets               # Image and color assets
├── Models/
│   ├── JobApplication.swift      # @Model data class + enums (type, status, season, compensation, currency)
│   └── EmailParser.swift         # NLP + regex parsing engine
└── Views/
    ├── RootView.swift            # Tab bar (Applications, Parse, Profile)
    ├── ApplicationView.swift     # Main list with search, sort, filter
    ├── JobCardView.swift         # Card component with themed avatars
    ├── JobDetailView.swift       # Add/edit form: state, save, type/status/season/date/notes sections
    ├── JobDetail/
    │   ├── SectionLabel.swift        # Shared label row used by detail sections
    │   ├── JobInfoSection.swift      # Hero header: logo picker, position, company name
    │   ├── CompensationSection.swift # Hourly/Salary + currency + period picker
    │   └── ResumeSection.swift       # Inline resume pills, library sheet, document picker
    ├── EmailParserView.swift     # Paste email → extract fields UI
    ├── ProfileView.swift         # Stats dashboard + CSV export
    ├── OnboardingView.swift      # First-launch walkthrough
    ├── PillUI.swift              # Reusable pill components
    ├── SelectablePill.swift      # Selectable pill used in JobDetailView pickers
    └── DarkStatusPill.swift      # Status pill with colored dot indicator
```

---

## Screenshots/ Demos


| Onboarding (GIF) | Applications (GIF) | Detail View | Email Parser (GIF) | Profile |
|:---:|:---:|:---:|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/2cb5632b-f4e2-4e21-bbfa-2914f06d0339" width="160"/> | <img src="https://github.com/user-attachments/assets/6d3b921d-8b80-4fb8-a591-c335e94eca94" width="160"/> | <img src="https://github.com/user-attachments/assets/0ee55add-8270-4401-a0fb-f41bb57b1100" width="160"/> | <img src="https://github.com/user-attachments/assets/bd6d5a11-f755-4b5d-b011-34f6a05db673" width="160"/> | <img src="https://github.com/user-attachments/assets/5786b23f-8874-443b-b60e-89a9b1f1477d" width="160"/> |

---

## Getting Started

1. Clone the repo
   ```bash
   git clone https://github.com/marcanjoul/AppNest.git
   ```
2. Open `AppNest/AppNest.xcodeproj` in Xcode 15+
3. Build and run on a simulator or device running iOS 17+

No API keys or external dependencies required.

---

## What I Learned

- SwiftData as a modern replacement for Core Data — how `@Model`, `@Query`, and `ModelContainer` simplify persistence
- Apple's NaturalLanguage framework for on-device named entity recognition
- Building a centralized design system in SwiftUI with a `Theme` enum
- Hybrid parsing strategies combining NLP, regex, and Apple's data detectors
- SwiftUI patterns: `@Environment(\.modelContext)`, `@AppStorage`, `NavigationStack`, `.searchable`, `.sheet`

---

## License

MIT License — Copyright (c) 2025 Mark Anjoul

See [LICENSE](LICENSE) for full text.
