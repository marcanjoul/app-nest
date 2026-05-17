# App Nest

An iOS app for tracking job and internship applications, built with SwiftUI.

---

## Features

**Track applications** — Add jobs manually with company, position, type, status, season, compensation (hourly or salary, with a currency picker), date, notes, and a resume attachment. Edit or delete anytime.

**Parse emails with on-device AI** — Paste a job confirmation email and AppNest extracts the company name, position, status, and date automatically using Apple's NaturalLanguage framework. Email parsing does not require an external API.

**Search, sort, and filter** — Find applications instantly by company or position. Sort by date or company name. Filter by status with horizontal chips or the toolbar menu.

**Profile, stats, and resumes** — See your total applications, pipeline breakdown, most-applied companies, and saved resumes at a glance. Export applications as a CSV.

**Company logos** — AppNest can fetch company logos through Logo.dev when API keys are configured. Users can also upload a custom logo image manually.

**Onboarding** — A clean three-screen walkthrough on first launch.

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData (SQLite) |
| NLP / Parsing | Apple NaturalLanguage framework (NLTagger) + regex patterns + NSDataDetector |
| Logo Lookup | Logo.dev API |
| Architecture | MVVM-ish — `@Model` + `@Query` replace the traditional ViewModel |
| Current Deployment Target | iOS 26.0 |

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
│   ├── EmailParser.swift         # NLP + regex parsing engine
│   ├── LogoFetcher.swift         # Logo.dev lookup and image fetcher
│   └── NotificationManager.swift # Local reminder scheduling
└── Views/
    ├── RootView.swift            # Tab bar (Applications, Parse, Profile)
    ├── ApplicationView.swift     # Main list with search, sort, filter
    ├── JobCardView.swift         # Card component with themed avatars
    ├── JobDetailView.swift       # Add/edit form: state, save, reminders, type/status/season/date/notes sections
    ├── JobDetail/
    │   ├── SectionLabel.swift        # Shared label row used by detail sections
    │   ├── JobInfoSection.swift      # Hero header: logo picker, position, company name
    │   ├── CompensationSection.swift # Hourly/Salary + currency + period picker
    │   └── ResumeSection.swift       # Inline resume pills, library sheet, document picker
    ├── EmailParserView.swift     # Paste email → extract fields UI
    ├── ProfileView.swift         # Profile, resume manager, stats summary, CSV export
    ├── ProfileStatsView.swift    # Deeper analytics view
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

### Requirements

- macOS with Xcode installed
- Xcode version compatible with the project format and iOS 26 SDK
- iOS 26 simulator or device, unless you lower the deployment target yourself
- A Logo.dev account if you want automatic company logo fetching

The project currently has `IPHONEOS_DEPLOYMENT_TARGET = 26.0`. If you want broader device support, change the deployment target in Xcode and verify that all SwiftUI/SwiftData APIs still compile on the lower iOS version.

### Setup

1. Clone the repo
   ```bash
   git clone https://github.com/marcanjoul/AppNest.git
   cd AppNest
   ```
2. Create `AppNest/APIKeys.swift` from the example below.
3. Open `AppNest.xcodeproj` in Xcode.
4. Select an iOS simulator or connected device.
5. Build and run.

### Logo.dev API Keys

`AppNest/APIKeys.swift` is intentionally gitignored so real credentials do not get committed. A fresh clone needs this file because `LogoFetcher` references `APIKeys`.

Create a new file at `AppNest/APIKeys.swift` and add:

```swift
enum APIKeys {
    static let logoDevPublicKey = "pk_YOUR_PUBLISHABLE_KEY_HERE"
    static let logoDevSecretKey = "sk_YOUR_SECRET_KEY_HERE"
}
```

You can find the key shape in `AppNest/APIKeys.example.swift`.

### Offline Behavior

Core application tracking, SwiftData persistence, CSV export, resume attachment metadata, onboarding, search, sort, filtering, and email parsing are local app features. Automatic company logo lookup requires internet access and valid Logo.dev credentials.

### Local Build Check

From a machine where `xcode-select` points to full Xcode, you can inspect or build the project with:

```bash
xcodebuild -list -project AppNest.xcodeproj
```

If `xcodebuild` reports that the active developer directory is CommandLineTools, switch to Xcode first:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

---

## What I Learned

- SwiftData as a modern replacement for Core Data — how `@Model`, `@Query`, and `ModelContainer` simplify persistence
- Apple's NaturalLanguage framework for on-device named entity recognition
- Building a centralized design system in SwiftUI with a `Theme` enum
- Hybrid parsing strategies combining NLP, regex, and Apple's data detectors
- SwiftUI patterns: `@Environment(\.modelContext)`, `@AppStorage`, `NavigationStack`, `.searchable`, `.sheet`
- Document picking, security-scoped bookmarks, local notifications, and CSV export

---

## License

MIT License — Copyright (c) 2025 Mark Anjoul.
