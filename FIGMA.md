# Figma — Design System & Prototype

**File:** https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH

Built from the Swift source, not from `DESIGN.md`. Where the two disagree, the code wins —
see [Corrections](#corrections-to-designmd).

Light and Dark are one mode switch on the `Color` variable collection. No duplicated artwork.

---

## Component → code map

This is a manual Code Connect map. Figma's Code Connect API requires an Organization or
Enterprise plan (this account is on `student`), so the mapping lives here instead. On upgrade,
these rows translate straight into `.figma.swift` connect files.

| Figma component | Variants | Swift symbol | Source |
|---|---|---|---|
| [StatusPill](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=12-381) | 7 | `DarkStatusPill` | `Views/Components/Pills/PillUI.swift` |
| [TypeTag](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=15-189) | 13 | `DarkTypeTag` | `Views/Components/Pills/PillUI.swift` |
| [SelectablePill](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=15-200) | 2 | `SelectablePill` | `Views/Components/Pills/PillUI.swift` |
| [StatChip](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=16-175) | 14 | `StatChip` | `Views/Components/Pills/PillUI.swift` |
| [FilterToken](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=17-66) | 4 | `FilterToken` | `Views/Components/Pills/PillUI.swift` |
| [CompactFilterChip](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=17-77) | 2 | `CompactFilterChip` | `Views/Components/Pills/PillUI.swift` |
| [ResumePill](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=17-118) | 8 | `ResumePill` | `Views/Components/Pills/PillUI.swift` |
| [CompanyAvatar](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=17-138) | 6 | `DarkJobCardView.avatarView` | `Views/Components/Cards/JobCardView.swift` |
| [JobCard](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=17-156) | 1 | `DarkJobCardView` | `Views/Components/Cards/JobCardView.swift` |
| [SaveButton](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=19-20) | 3 | `JobDetailView.saveBar` | `Views/Screens/JobDetailView.swift` |
| [CancelButton](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=19-23) | 1 | `JobDetailView.saveBar` | `Views/Screens/JobDetailView.swift` |
| [NavCircleButton](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=19-40) | 4 | `JobDetailView.floatingNavBar` | `Views/Screens/JobDetailView.swift` |
| [SectionLabel](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=19-67) | 4 | `SectionLabel` | `Views/Components/JobDetail/PickerSections.swift` |
| [GlassCard](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=19-84) | 2 | `Surface` / `.surface(cornerRadius:)` | `Design System/Theme/ViewModifiers.swift` |
| [SearchBar](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=21-13) | 1 | `ApplicationView.searchFilterRow` | `Views/Screens/ApplicationView.swift` |
| [SortButton](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=21-17) | 1 | `ApplicationView.searchFilterRow` | `Views/Screens/ApplicationView.swift` |
| [CycleChip](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=21-32) | 2 | `ApplicationView.cycleSelectorChip` | `Views/Screens/ApplicationView.swift` |
| [HeaderActions](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=21-41) | 1 | `ApplicationView.headerActionButtons` | `Views/Screens/ApplicationView.swift` |
| [TabBar](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=22-72) | 3 | `RootView` | `Views/Screens/RootView.swift` |
| [CardRowHeader](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=24-64) | 4 | `CardRowHeader` | `Views/Screens/AddMenuView.swift` |
| [JobInfoSection](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=25-39) | 1 | `JobInfoSection` | `Views/Components/JobDetail/JobInfoSection.swift` |
| [FormSection](https://www.figma.com/design/zi4ChBz3BykixFyN8A61ZH?node-id=25-48) | 1 | `ChoiceSection` | `Views/Components/JobDetail/PickerSections.swift` |

Plus **70 icon components** on the `Icons` page, named `icon/<lucide-name>` — outlines extracted
from the bundled `Design System/lucide.ttf`, so they match `AppIcon` exactly.
`AppIcon.glyphs` maps SF-Symbol-style names onto these; several names share one glyph.

## Screens

`01 Applications` · `01b Applications (edit)` · `02 Add a Job` · `03 Job Detail` ·
`03b Job Detail (optional)` · `04 Profile` · `05 Onboarding ×3` · `06 Cycle Picker` ·
`07 Insights` · `08 Parse Email` · `09 CSV Import Preview`, plus 5 dark-mode copies.

Prototype flows: **First launch — Onboarding** and **Main app — Applications**.
Transitions use the real motion tokens from `Animations.swift`
(`appSmooth` = `cubic-bezier(0.22, 1, 0.36, 1)` @ 0.25s, `appCrisp` @ 0.18s).

## Token mapping

| Figma collection | Modes | Source |
|---|---|---|
| `Primitives` | Value | every distinct literal RGB in `Theme.swift` / `PillUI.swift` |
| `Color` | Light, Dark | semantic tokens; trait-dependent values mirror the `UIColor { trait in … }` closures |
| `Scale` | Value | radii, spacing and sizes read off the call sites |

Every variable carries an iOS `codeSyntax` string (e.g. `Theme.cardFill`, `.opacity(0.13)`).

**Note on alpha:** Figma's bound colour variables own the paint's alpha — `opacity` on the paint
is ignored. So each translucent tint (`color.opacity(0.12)` etc.) is its own variable with the
alpha baked in. That's why the file has ~370 variables for a fairly small palette.

---

## Corrections to DESIGN.md

`DESIGN.md` has drifted from the code. Verified differences:

| Item | DESIGN.md | Actual |
|---|---|---|
| `cardRadius` | 20 | **24** |
| `background` | `#FFFFFF` / `#000000` | **`#F6F7F9` / `#121314`** |
| `cardFill` | `#F2F2F7` / `#1C1C1F` @85% | **`#FFFFFF` / `#1D1E20`**, opaque |
| `cardBorder` light | `#000000` @4% | **`#262B30` @10%** |
| `textSecondary` | `secondaryLabel` | **`white(0.36)` / `white(0.72)`** |
| `sectionLabelSize` / tracking | 11pt / +0.8 / UPPERCASE | **13pt / 0 / `textCase(nil)`** |
| Statuses | 5 | **7** — adds `Ghosted`, `Job Removed` |
| Status colours | one set | **two** — `Theme.statusStyle` (mode-aware, light = raw × 0.62) and `ApplicationStatus.color` (flat) |
| Motion | springs (response/damping) | **timing curves** |
| Card shadow | black 8%, r12, y4 | **black 1.6%, r3, y1** |
| Detail-screen logo | 60×60 rounded rect, pencil badge | **72pt circle, camera badge** |
| Card avatar radius | 16 | **20** |
| Icons | "SF Symbols only" | **bundled Lucide font** (`lucide.ttf`) |
| `EmailParserView` | "pushed from Tab 2" | **never instantiated — dead code**; the real flow is the expandable card in `AddMenuView` |

Three further code-level findings from this work, all since resolved:

- `CompensationSection` passed `icon: "banknote"`, which was absent from `AppIcon.glyphs`, so the
  Salary pill fell back to `circle`. **Fixed** — `banknote` (U+E056) is now mapped, and the Figma
  icon set carries the matching glyph.
- `ActivityHeatmapView` used `LazyVGrid(columns: 7)`, which fills row-major — so 90 days stacked
  into a tall 7×13 block and no column corresponded to a week. **Fixed** — it is now
  `LazyHGrid(rows: 7)`, which fills column-major, plus leading blanks so every column is a real
  calendar week. Renders 7×14 at 192pt wide.
- `JobInfoSection` indexed its logo tint with `abs(key.hashValue)`, which Swift reseeds per process,
  so the logo changed colour every launch. **Fixed** — it now calls `Theme.avatarFill(for:)`, the
  same `stableHash` path the job card uses.
