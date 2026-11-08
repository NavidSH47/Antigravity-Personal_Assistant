# Software Design Document (SDD)
## Project: NSH Pulse (Lightweight Personal Assistant & Daily Pulse)
**Document Version:** 2.4.0  
**Target Platform:** Android (API 26+, optimized for Samsung Galaxy A12 & modern devices), Flutter Web (Chrome), Windows Desktop  
**Repository:** Local git repository initialized (`main`)  
**Status:** Approved Architecture & Specification (Includes Version 2.4.0 Evolution Backlog: Theme Harmonization, Postpone Refinements, Task Progression & Minimization, Centered Shamsi Header, Label Pool Management, and Console Video Game Art Architecture)

---

## 1. System Overview & Rebranding: NSH Pulse

### 1.1 Project Rebranding: NSH Pulse
The application is officially rebranded from **NSH Assistant** to **NSH Pulse**. 

The brand identity reflects the core heartbeat of the application: a zero-latency, local-first companion unifying daily agenda planning, task execution streams, and entertainment tracking.

### 1.2 Brand Asset Integration (`Logo.jpeg`)
- **Asset Placement:** `Logo.jpeg` resides at the project root and is declared as an asset in `pubspec.yaml`:
  ```yaml
  flutter:
    uses-material-design: true
    assets:
      - Logo.jpeg
  ```
- **Top Bar Header Architecture:**
  - The previous text-only header (`⚡ NSH Assistant`) is replaced with a unified branded component:
    - **Logo Badge:** A high-fidelity, anti-aliased image avatar (`Logo.jpeg`) rendered via `ClipRRect` (radius 8dp, size 28x28dp) with a subtle accent border matching the active theme vibe.
    - **Branded Title:** `NSH Pulse` rendered with the dynamic theme gradient shader (`ShaderMask`) and bold typography (18sp, `FontWeight.w900`, tracking -0.3).
- **Application Identifiers:**
  - Android Manifest label updated from `nsh_assistant` to `NSH Pulse` (`android:label="NSH Pulse"`).
  - Flutter entry title updated to `NSH Pulse` in `MaterialApp(title: 'NSH Pulse')`.
  - Web title updated to `<title>NSH Pulse</title>` in `web/index.html`.

---

## 2. Core Functional Pillars

1. **Contextual Day-Planner & Shamsi Agenda:** Solar Hijri calendar integration, official Iranian holidays, custom reminders, and RTL calendar grid.
2. **Split-Stream Task Engine ("Daily Pulse"):** Daily Focus vs. General Backlog/Orbit, multi-line notes, 3-state execution (`Done`, `Tomorrow`, `Cancel`), dynamic RTL detection, compact mini-tasks, and touch/drag reordering with boundary auto-scroll.
3. **Universal Entertainment Ledger:** Books, TV Shows, Movies, and Video Games with metric progress tracking, half-point ratings (1.0 - 10.0), persistent offline cover art disk caching, unified modal label picker, and automated multi-source cover fetcher.
4. **Adaptive Aesthetics & Dynamic Typography:** 11 distinct high-contrast Dark Vibe palettes + cross-platform typography without external font bloat.

---

## 3. Detailed Specifications for Completed Changes

### 3.1 Change 1: Mobile Typography Engine & Offline Font Manager
#### Problem Statement
On physical mobile devices (specifically Samsung Galaxy A12 running Android 11/12 with One UI), switching between `Comic Sans`, `Rounded Bold`, and `Vazirmatn` produces no visual change compared to the system default sans font.

#### Root Cause Analysis
- **System Font Isolation:** Android's internal `/system/fonts` directory exclusively contains `Roboto` (for Latin) and `Noto Sans Arabic` (for Perso-Arabic scripts). Desktop fonts like `Comic Sans MS`, `Arial Rounded MT Bold`, or `Georgia` do not exist on Android.
- **Web Font Limitations:** The prior HTML `<link>` tag approach in `web/index.html` functions exclusively in Chrome Web Canvas/DOM renderers. Native Android binaries require bundled offline font assets.
- **Fallback Resolution Failure:** Without locally packaged font binaries, Flutter's engine falls back to Android's default system typography.

#### Architectural Solution
1. **Font Bundling Strategy:**
   - Bundled offline `.ttf` assets in `assets/fonts/` for strict air-gapped zero-latency operation:
     - **Comic Neue:** Friendly, informal Latin typeface paired with system fallbacks.
     - **Quicksand:** Smooth, soft-rounded bold typeface for friendly UI aesthetics.
     - **Fira Code:** Fixed-width terminal/developer typography.
     - **Lora:** Literary editorial serif typography.
     - **Default Sans:** Standard clean system sans.
   *(Note: See Section 8.1.1 for the planned removal of Vazirmatn).*

---

### 3.2 Change 2: Responsive Mobile Layout & Anti-Overflow Constraint System
#### Problem Statement
On narrow mobile screens (such as Samsung Galaxy A12 with a 360dp–384dp logical width and user-adjusted font scaling), UI controls and headers extend out of their bounding boxes. Specifically:
- `Shamsi Calendar` and action buttons overflowed the top header row in `ShamsiAgendaBanner`.
- `+ Add for This Day` / `+ Add for Today` overflowed the Today's Focus header row when paired with long Jalali date strings.
- Quick navigation buttons caused horizontal clipping on narrow displays.

#### Architectural Solution
1. **Adaptive Agenda Header (`ShamsiAgendaBanner`):**
   - Implemented `LayoutBuilder` on the top banner:
     - If available width `< 380dp`: Date badge and month/year column are placed on the first row with `Expanded`. Action buttons wrap gracefully to a secondary compact row.
     - If available width `≥ 380dp`: Standard single-row horizontal layout.
2. **Adaptive Focus Header (`main.dart`):**
   - Wrapped the title section in `Expanded` and `Flexible` with `TextOverflow.ellipsis`.
   - Compact button labels on mobile (`+ Add` instead of verbose `+ Add for This Day`).
3. **Quick Navigation Bar Resilience:**
   - Centered date navigation bar powered by `FittedBox` and dynamic spacing, eliminating horizontal clipping entirely.

---

### 3.3 Change 3: Entertainment Ledger — Media Removal & Lifecycle Management
#### Architectural Solution
1. **UI Action Integration:**
   - Added trash icon button in List View, Grid View, and Edit Media modal.
2. **Confirmation Modal:**
   - Tapping Delete displays an `AlertDialog` confirming removal and notifying the user that completed linked tasks remain preserved.
3. **Data Layer & Cascade Handling (`StorageService` & `main.dart`):**
   - Decouples linked tasks (`linkedMediaId: null`) to prevent dangling reference exceptions while preserving task history.
   - Transient `SnackBar` with `Undo` action to restore accidentally deleted items.

---

### 3.4 Change 4: Automated Cover Fetching Engine & Free Multi-Source APIs
#### Best Free Public Sources for All 4 Media Types
| Media Type | Primary API | Auth Required | Capabilities & Endpoints | Fallback Source |
| :--- | :--- | :--- | :--- | :--- |
| **Books** | **Open Library Covers & Search API** | **None (100% Free)** | `https://openlibrary.org/search.json?q={title}&limit=5`<br>Poster endpoint: `https://covers.openlibrary.org/b/id/{cover_i}-L.jpg` | **Google Books API** |
| **TV Shows** | **TVMaze API** | **None (100% Free)** | `https://api.tvmaze.com/singlesearch/shows?q={title}` or `/search/shows?q={title}` | **iTunes Search API** |
| **Movies** | **iTunes Search API** | **None (100% Free)** | `https://itunes.apple.com/search?term={title}&entity=movie&limit=5` (high-res artwork) | **Cinemeta Catalog API** |
| **Video Games** | **Steam Store Search API** | **None (100% Free)** | `https://store.steampowered.com/api/storesearch/?term={title}&l=english&cc=US` (600x900 library posters) | **CheapShark API** / **LaunchBox** / **RAWG Console Fallback** |

> [!NOTE]
> **Video Game Platform Scope & Console Artwork Support:**  
> The default primary source (Steam Store Search) and CheapShark fallback exclusively index PC/Steam releases. Console titles and exclusives (Nintendo Switch, Wii, Game Boy, PlayStation, Xbox) are not indexed on Steam. A dedicated multi-platform fallback architecture using RAWG, LaunchBox Open Database, and Libretro Boxart CDNs is specified in **Section 8.3.6** to ensure full cover fetching for Nintendo and console games.

---

### 3.5 Change 5: Dynamic Context-Aware Backlog Assignment
- Backlog tasks feature a dynamic schedule button:
  - If viewing today: `⚡ Schedule Today`
  - If viewing another date: `📅 Assign to Day`
- Tapping binds the task's `targetDateJalali` directly to the active calendar date.

---

### 3.6 Change 6: Rebranding to "NSH Pulse" & Logo Asset Integration
- Full application rebranding across Android Manifest, Web index title, top AppBar avatar, and application package manifests.

---

### 3.7 Change 7: Redundant Label Cleanup
- Eliminated redundant `"Due Today"` label from `TaskCard` to maximize visual priority for task title and execution buttons.

---

## 4. Technical Architecture & File Modification Matrix

| File Path | Component | Changes Required (Version 2.4.0 Specification) |
| :--- | :--- | :--- |
| `pubspec.yaml` | Manifest | 1) Remove `Vazirmatn` font family declaration.<br>2) Add `cached_network_image: ^3.4.1` for persistent cover disk caching. |
| `assets/fonts/` | Asset Directory | Remove unused `Vazirmatn-Regular.ttf` and `Vazirmatn-Bold.ttf` binaries. |
| `lib/services/title_case_service.dart` | Text Formatting | **Refactor to Sentence Case:** Replace `TitleCaseTextInputFormatter` with `SentenceCaseTextInputFormatter` and `toSentenceCase()`. |
| `lib/services/rtl_detection_service.dart` | Typography / Bidi | **New Service:** Detect Persian/Arabic script to provide dynamic `TextDirection` for task items and text input boxes. |
| `lib/services/cover_cache_service.dart` | Media Caching | **New Service / Component:** Manage local persistent disk caching for fetched media covers so images are never re-downloaded. |
| `lib/services/cover_fetch_service.dart` | Media Cover Fetching | Add multi-platform console cover architecture: fallback to RAWG / LaunchBox / Libretro Boxart CDNs when Steam returns 0 results for console and Nintendo games. |
| `lib/services/media_label_service.dart` | Labels & Tags | 1) Remove default preset `'Masterpiece'`.<br>2) Add default preset `'Fantasy'`.<br>3) Expose label pool mutators allowing complete deletion of labels (both custom and default) from the persistent database. |
| `lib/services/storage_service.dart` | Persistence | Persist active label list in `SharedPreferences` so user deletions of default or custom labels persist across launches. |
| `lib/theme/app_theme.dart` | Theme & Palettes | 1) Remove `AppFontStyle.vazirmatn` and clean typography fallbacks.<br>2) **Theme Consolidation:** Merge Persian Turquoise dark teal background canvas/surface (`bgCanvas: #091319`, `bgSurface: #0F1F28`, `bgElevated: #162D3A`) into `Nordic Slate` with Nordic Slate's icy sky foreground colors (`accentPrimary: #38BDF8`), and eliminate `ThemeVibe.persianTurquoise` completely.<br>3) **Purple Rework:** Remove `Deep Lavender` (`ThemeVibe.electricLavender`). Deepen `Deep Amethyst` with high-contrast pitch blacks (`bgCanvas: #05020A`) and bold royal jewel purple accents (`accentPrimary: #B026FF` / `#A855F7`). |
| `lib/widgets/shamsi_agenda_banner.dart` | Agenda & Calendar | 1) Restore `+ Event` action button for adding custom events/reminders.<br>2) Dynamic calendar dot colors: Orange for default holidays, pink for birthdays, blue for custom dates.<br>3) **Centered Header Architecture:** Horizontally center top bar date display, and horizontally center action buttons (`+ Event`, `Pick Date`, `Calendar`) with responsive dynamic spacing matching the navigation bar below. |
| `lib/widgets/task_card.dart` | Task Card UI | 1) Compact mini-tasks: collapse empty space and padding when task has no description notes.<br>2) **Postpone Button Evolution:** Rename `'Tomorrow'` button to `'Postpone'`; dynamically display postponement multiplier (`Postpone 2x`, `Postpone 3x`) directly on the button when postponed ≥2x; completely remove the standalone `'Postponed (1x)'` text box.<br>3) **Vertically Centered Reorder Handle:** Vertically center the drag handle (`dragIndex != null`) on the left side of the card across the card's full height.<br>4) Holding Postpone button opens Shamsi date picker sub-menu (no text box).<br>5) 3-second hold on card opens edit modal.<br>6) RTL text direction support for Persian titles and descriptions. |
| `lib/widgets/media_card.dart` | Media Card UI | 1) Desaturate "Enter Notes" placeholder text color to subtle muted tone.<br>2) Integrate persistent disk image cache renderer (`SafeCoverImage` / `CachedNetworkImage`).<br>3) Add 3-second hold gesture detector on List and Grid cards to open centralized media edit modal. |
| `lib/widgets/safe_cover_image.dart` | Image Renderer | Integrate disk caching layer (`CachedNetworkImage` with CORS fallback) to eliminate repetitive network downloads. |
| `lib/main.dart` | Core Application | 1) **Task Sinking:** Automatically move completed (`Done`) tasks to the bottom of Today's Focus and Backlog lists.<br>2) **Collapsible Task Streams:** Add list minimization (collapsible lists) for Today's Focus and Backlog toggled via an arrow icon only (no text labels).<br>3) **Progress Bar & Status Counters:** Display total, Done, and Cancelled task counts in section headers, paired with a themed horizontal progress bar dynamically styled by `palette.accentPrimary` or gradient.<br>4) **Label Sub-Menu Overhaul:** Replace vertical single-column checkbox list with compact small button chips in a responsive `Wrap`, remove `(Custom)` taglines, and enable long-press to permanently remove any label (default or custom) from the database.<br>5) **Recently Added Sorting:** Rename entertainment sorting option `'custom'` from `'Custom Order'` to `'Recently Added'`.<br>6) Auto-scroll on drag reorder near viewport top/bottom edges.<br>7) Dynamic Persian RTL auto-detection on text fields. |

---

## 5. Verification & Testing Strategy

### 5.1 Device & Display Verification
- **Target Device:** Samsung Galaxy A12 (Android 11/12, One UI Core, screen size: 720 x 1600 px @ ~270 ppi, logical width: 360dp–384dp).
- **Verification Checklist (Version 2.4.0):**
  - [ ] **Font Elimination:** App builds cleanly without `Vazirmatn`; Persian text falls back smoothly to Android's native system Noto Sans Arabic without missing glyphs.
  - [ ] **Sentence Case:** Typing in Task and Media dialogs capitalizes only the first letter of each sentence; subsequent words remain lowercase unless explicitly typed in uppercase.
  - [ ] **Custom Event Creation:** Tapping `+ Event` opens modal, creates custom birthday or milestone event, and displays it in the agenda banner.
  - [ ] **Calendar Dot Colors:** Holiday-only dates display an orange dot (`#F59E0B`). Dates with birthdays display a pink dot (`#EC4899`). Dates with custom events display a blue dot (`#60A5FA`).
  - [ ] **Top Bar Centering & Responsive Actions:** Top bar date display is horizontally centered. `+ Event`, `Pick Date`, and `Calendar` buttons are centered with responsive dynamic spacing matching the navigation bar below.
  - [ ] **Postpone Button & Multiplier:** Button label reads "Postpone". Postponing multiple times dynamically displays `Postpone 2x`, `Postpone 3x` on the button itself. The standalone `Postponed (1x)` text box is completely removed.
  - [ ] **Vertically Centered Reorder Handle:** Drag handle (`Icons.drag_indicator`) is vertically centered on the left side of the task card across the card's full height.
  - [ ] **Compact Mini-Tasks:** Tasks without description render with tight padding, collapsed spacing, and no empty gap beneath the title.
  - [ ] **Drag Auto-Scroll:** Dragging a task to within 80dp of the top or bottom viewport edge smoothly auto-scrolls the task list.
  - [ ] **Theme Consolidation & Purple Rework:**
    - Persian Turquoise background canvas (`#091319`, `#0F1F28`, `#162D3A`) is merged into Nordic Slate with Nordic Slate's icy sky foreground colors (`#38BDF8`); Persian Turquoise is removed from the theme list.
    - Deep Lavender is removed entirely.
    - Deep Amethyst is deepened with pitch-black plum surfaces (`#05020A`) and bold, vibrant jewel purple accents (`#B026FF`).
  - [ ] **Persian RTL Support:** Persian task titles and notes align to the right with RTL text direction. Add Task input box switches dynamically to RTL when first character is Persian.
  - [ ] **3-Second Card Hold:** Holding task card for 3 seconds opens edit dialog. Adding notes to an originally blank mini-task expands the card gracefully.
  - [ ] **Done Tasks Sinking:** Marking a task as `Done` automatically moves it to the bottom of the list in both Today's Focus and Orbit & Backlog.
  - [ ] **Minimizable Task Lists:** Today's Focus and Orbit & Backlog lists can be minimized/collapsed using an arrow-only icon button (no text labels).
  - [ ] **Task Status Counters & Themed Progress Bar:** Section headers display Total, Done, and Cancelled task counts, accompanied by a linear progress bar dynamically colored with the active theme's accent color.
  - [ ] **Cover Art Cache:** Once a cover art image is fetched, closing and reopening the app or navigating between pages loads the cover instantaneously from local disk cache with 0 network calls.
  - [ ] **Nintendo & Console Cover Art Architecture:** Game cover fetching architecture handles console and Nintendo titles (RAWG / LaunchBox / Libretro) when games are absent from Steam.
  - [ ] **Recently Added Sort:** Entertainment sort dropdown displays "Recently Added" instead of "Custom Order".
  - [ ] **Label Defaults Rework:** "Masterpiece" is removed from default presets; "Fantasy" is added as a default preset.
  - [ ] **Compact Label Sub-Menu:** The label sub-menu modal displays tags as compact small buttons in a space-filling `Wrap` layout instead of a single-column scrolling checkbox list.
  - [ ] **Long-Press Label Deletion:** Long-pressing any label button in the sub-menu deletes it permanently from the database; `(Custom)` taglines are removed; default presets can also be deleted.
  - [ ] **3-Second Media Tile Hold:** Holding any media tile (in either List View or Grid View) for 3 seconds opens the centralized media edit dialog.

---

## 6. Implementation Rollout Milestones

1. **Milestone 1:** Rebranding, `Logo.jpeg` integration, and "Due Today" removal.
2. **Milestone 2:** Responsive anti-overflow fixes for `ShamsiAgendaBanner` and Focus headers on mobile (Samsung A12).
3. **Milestone 3:** Offline font bundling (`Comic Neue`, `Quicksand`, `Fira Code`, `Lora`) and cross-platform fallbacks.
4. **Milestone 4:** Media removal workflow with confirmation dialog and cascade handling.
5. **Milestone 5:** `CoverFetchService` multi-source free APIs & interactive auto-fetch modal.
6. **Milestone 6:** "Assign Today" renaming & context-aware date binding.
7. **Milestone 7:** Full regression testing on Android and Web.
8. **Milestone 8:** App Icon Generation (Android mipmaps, Web icons, Windows ico).
9. **Milestone 9:** Shamsi Calendar Library Integration (`persian_datetime_picker` & `persian_number_utility`).
10. **Milestone 10:** Input formatting system architecture.
11. **Milestone 11:** Auto Fetch Cover Fixes, Media Sources Catalog, and `SafeCoverImage`.
12. **Milestone 12:** Horizontal Swipe Transition between Daily Pulse & Entertainment streams.
13. **Milestone 13 (General):** Remove Vazir font entirely; implement Sentence Case text formatting (`SentenceCaseTextInputFormatter`).
14. **Milestone 14 (Daily Pulse UX):** Restore `+ Event` custom reminder system; implement dynamic multi-colored calendar dots (Orange/Pink/Blue).
15. **Milestone 15 (Daily Pulse Tasks):** Postpone button Shamsi date postponement sub-menu; compact mini-tasks layout; 3-second card hold edit workflow; drag auto-scrolling near edges.
16. **Milestone 16 (Styling & RTL):** Palette overhaul and dynamic Persian RTL detection for task cards and input fields.
17. **Milestone 17 (Entertainment Core):** Persistent cover art disk cache; desaturated notes placeholder text; 3-second media tile hold to edit in list and grid views.
18. **Milestone 18 (Theme Consolidation & Purple Rework):** Merge Persian Turquoise background into Nordic Slate; remove Persian Turquoise; remove Deep Lavender; deepen Deep Amethyst with pitch-black surfaces and bold purple.
19. **Milestone 19 (Daily Pulse Execution & Header Architecture):** Postpone button renaming and dynamic multiplier (`Postpone 2x`); eliminate standalone Postponed text box; vertically center task drag handle; center Shamsi top bar date and action buttons with dynamic spacing; auto-sink completed (`Done`) tasks to list bottom; collapsible task lists with arrow-only toggle; task status breakdown counters with theme-colored progress bar.
20. **Milestone 20 (Entertainment Catalog & Label Database):** Rename "Custom Order" sorting to "Recently Added"; multi-platform console & Nintendo game cover architecture; replace "Masterpiece" preset with "Fantasy"; compact button wrap label sub-menu; long-press label database deletion; removal of `(Custom)` tagline and support for deleting default labels.

---

## 7. Extended Architecture & Bug Fix Specifications (Version 2.1.0 & 2.2.0)

### 7.1 Multi-Platform App Icon Generation
- Android mipmaps generated at `mdpi` (48x48), `hdpi` (72x72), `xhdpi` (96x96), `xxhdpi` (144x144), and `xxxhdpi` (192x192).
- Web icons generated for `web/favicon.png` (32x32) and progressive web app icons `Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png`.
- Windows Desktop icon generated at `windows/runner/resources/app_icon.ico` (256x256).

### 7.2 Reminders Cleanup & Official Persian Libraries Integration
- **Reminder Cleanup Context:** The legacy `+ Reminder` button and `'No reminders or events scheduled for this day.'` placeholder were removed from `ShamsiAgendaBanner` in v2.1.0 to eliminate confusing checklist checkboxes on official holidays. *(See Section 8.2.1 for the planned reintroduction of dedicated custom event creation).*
- **Existing Shamsi Libraries:** Integrated `persian_datetime_picker` (3.2.0) and `persian_number_utility` (1.1.6). Added `🗓️ Pick Date` button to the Shamsi header and custom date picker to task rescheduling modal.

### 7.3 Auto Fetch Cover & Robust Cover Image Rendering (`SafeCoverImage`)
- **Android Manifest:** Added missing `android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE`.
- **URL Normalization:** Double slashes in path components (e.g. `https://images.launchbox-app.com//e9438ab4...`) are sanitized to single slashes.
- **CORS & CDN Fallback:** `SafeCoverImage` incorporates `images.weserv.nl` CORS fallback for Flutter Web and CDNs blocking direct access without CORS headers.
- **User-Agent:** Added descriptive client User-Agent headers to all API queries in `CoverFetchService`.

### 7.4 Horizontal Swipe Page Transition
- Segmented views (`Daily Pulse` and `Entertainment`) are wrapped in a root `PageView` powered by `_pageController` with synchronized segment button state.

### 7.5 UX & Calendar Harmonization (Version 2.2.0)
- **4:3 Posters & Game Covers:** Video games search returns vertical library posters (`library_600x900_2x.jpg` from Steam and CheapShark). All covers enforce 3:4/4:3 aspect ratios with `BoxFit.cover` inside anti-aliased containers so non-4:3 images are cropped and never stretched.
- **Media Update Validation:** `_showUpdateProgressDialog` enforces non-negative progress, positive capacity, and strictly validates that progress cannot exceed capacity (`cur <= tot`) with inline alerts.
- **Assign to Day Renaming:** Renamed backlog action label from `'📅 Schedule for Day'` to `'📅 Assign to Day'`.
- **Tomorrow Button Tooltip Decoupling:** Removed `onLongPress` date picker interception from the Tomorrow button; holding the button displays a descriptive Tooltip explaining the action. *(See Section 8.2.3 for the planned sub-menu date picker evolution).*
- **Centered Calendar Quick Navigation & Month Controls:** Date navigation is centered with dynamic spacing and features `« Month` and `Month »` navigation buttons powered by `DateNavigationService.shiftMonths`.
- **Gregorian Date Picker:** "Pick Date" in `ShamsiAgendaBanner` opens standard Gregorian `showDatePicker` and converts selected dates to Solar Hijri.
- **Comprehensive Shamsi & Global Holidays:** Added official observances and global celebrations to `ShamsiEvent.defaultEvents`, including World Diabetes Day (23rd Aban) and International Men's Day (28th Aban).
- **Media Card Under-Cover Layout:** Reorganized `MediaCard` list view: cover and title/labels reside in the top section, while description notes, rating/progress, and action buttons span the full width beneath the cover to prevent element overflow.
- **Today Highlight in Month Grid:** Today's date cell in the Shamsi calendar month grid features an accent border (`widget.palette.accentPrimary`) for instant visual identification.

---

## 8. Planned Architecture & Feature Enhancements (Version 2.4.0 Specification)

This section contains the comprehensive architectural blueprints, data models, interaction designs, and implementation specifications for the next iteration of NSH Pulse.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 NSH PULSE VERSION 2.4.0                                │
├─────────────────────────┬──────────────────────────────┬───────────────────────────────┤
│         GENERAL         │         DAILY PULSE          │         ENTERTAINMENT         │
├─────────────────────────┼──────────────────────────────┼───────────────────────────────┤
│ • Remove Vazirmatn Font │ • Restore + Event System     │ • Cover Art Disk Caching      │
│ • Universal Sentence    │ • Multi-Color Calendar Dots  │ • Desaturated Note Hint       │
│   Case Formatting       │ • Centered Top Bar & Actions │ • Compact Button Wrap Submenu │
│                         │ • "Postpone" + Multiplier 2x │ • Long-Press Label Deletion   │
│                         │ • Remove "Postponed 1x" Box  │ • Delete Default & Custom Tags│
│                         │ • Centered Left Drag Handle  │ • "Fantasy" Default Preset    │
│                         │ • Sinking "Done" Tasks       │ • "Recently Added" Sort Order │
│                         │ • Collapsible Lists (Arrow)  │ • Multi-Platform / Console    │
│                         │ • Themed Progress Bar        │   Game Cover Architecture     │
│                         │ • Compact Mini-Tasks         │   (Nintendo, PS, Xbox, RAWG)  │
│                         │ • Persian RTL Auto-Detection │ • 3-Second Tile Hold to Edit  │
│                         │ • Persian/Nordic Vibe Merge  │                               │
│                         │ • Pitch-Black Deep Amethyst  │                               │
└─────────────────────────┴──────────────────────────────┴───────────────────────────────┘
```

---

### 8.1 General Improvements

#### 8.1.1 Complete Removal of Vazirmatn Font Family
- **Problem Statement:** The latest typography patch attempting to bundle and map `Vazirmatn` offline continues to exhibit rendering inconsistencies across mobile Android platforms. Perso-Arabic typography on Android is natively handled with high fidelity by the system font (`Noto Sans Arabic` / `Roboto`), rendering the bundled `Vazirmatn` binaries redundant and increasing asset overhead.
- **Architectural Solution:**
  1. **Asset Deletion:** Remove `assets/fonts/Vazirmatn-Regular.ttf` and `assets/fonts/Vazirmatn-Bold.ttf`.
  2. **Manifest Cleanup:** Remove the `Vazirmatn` family entry from `pubspec.yaml`:
     ```yaml
     # Remove from pubspec.yaml:
     # - family: Vazirmatn
     #   fonts:
     #     - asset: assets/fonts/Vazirmatn-Regular.ttf
     #     - asset: assets/fonts/Vazirmatn-Bold.ttf
     ```
  3. **Enum & Fallback Simplification (`lib/theme/app_theme.dart`):**
     - Remove `vazirmatn` from `enum AppFontStyle`.
     - Update all font fallbacks: replace `'Vazirmatn'` with system fallbacks `['sans-serif']` (which Android maps to `Roboto` + `Noto Sans Arabic`).
     - Remove `Vazirmatn` selector tile from `lib/widgets/settings_drawer.dart`.

#### 8.1.2 Sentence Case Text Input Standard
- **Problem Statement:** The current input system mandates Title Case (`TitleCaseTextInputFormatter`), capitalizing the first letter of *every single word*. While appropriate for English book titles, this produces awkward, ungrammatical formatting for task descriptions, daily notes, checklist items, and mixed Persian-English inputs (e.g. *"Buy Two Liters Of Milk"* instead of *"Buy two liters of milk"*).
- **Architectural Solution:**
  1. **New Formatting Engine (`lib/services/sentence_case_service.dart`):**
     ```dart
     /// Capitalizes only the first letter of the input string or sentence.
     String toSentenceCase(String text) {
       final trimmed = text.trimLeft();
       if (trimmed.isEmpty) return text;
       final leadingWhitespace = text.substring(0, text.length - trimmed.length);
       final firstChar = trimmed[0].toUpperCase();
       final rest = trimmed.length > 1 ? trimmed.substring(1) : '';
       return '$leadingWhitespace$firstChar$rest';
     }

     /// TextInputFormatter enforcing sentence capitalization at typing time.
     class SentenceCaseTextInputFormatter extends TextInputFormatter {
       @override
       TextEditingValue formatEditUpdate(
         TextEditingValue oldValue,
         TextEditingValue newValue,
       ) {
         if (newValue.text.isEmpty) return newValue;
         final formatted = toSentenceCase(newValue.text);
         return newValue.copyWith(
           text: formatted,
           selection: newValue.selection,
         );
       }
     }
     ```
  2. **Global Input Migration:**
     - Replace `TitleCaseTextInputFormatter()` with `SentenceCaseTextInputFormatter()`.
     - Update all `TextField` instances: change `textCapitalization: TextCapitalization.words` to `textCapitalization: TextCapitalization.sentences`.
     - Update submission handlers: change `toTitleCase(...)` to `toSentenceCase(...)` across `main.dart` (Add Task, Edit Task, Add Media, Edit Notes).

---

### 8.2 Daily Pulse Improvements

#### 8.2.1 Restoration & Architecture of Custom Event & Reminder System
- **Context & User Clarification:**
  - *Why was the button removed?* In Milestone 9 / Section 7.2, the old `+ Reminder` button was removed together with the confusing checklist checkboxes to transform official calendar holidays into clean informational badges. However, this inadvertently eliminated the ability to add user-defined custom dates and personal reminders.
- **Architectural Solution:**
  1. **Header Action Integration (`lib/widgets/shamsi_agenda_banner.dart`):**
     - Add a clean `+ Event` action button in the top banner alongside the `🗓️ Pick Date` button:
       ```dart
       InkWell(
         onTap: () => _showAddCustomEventDialog(context),
         borderRadius: BorderRadius.circular(8),
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
           decoration: BoxDecoration(
             color: widget.palette.bgElevated,
             border: Border.all(color: widget.palette.borderSubtle),
             borderRadius: BorderRadius.circular(8),
           ),
           child: Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               Icon(Icons.add, size: 12, color: widget.palette.accentPrimary),
               const SizedBox(width: 4),
               Text(
                 'Event',
                 style: TextStyle(
                   fontSize: 11,
                   color: widget.palette.accentPrimary,
                   fontWeight: FontWeight.w600,
                 ),
               ),
             ],
           ),
         ),
       )
       ```
  2. **Add Custom Event Modal Dialog (`main.dart`):**
     - **Fields:**
       - **Event Title:** Sentence case formatted, dynamic RTL auto-detect.
       - **Target Shamsi Date:** Defaults to the currently viewed date, editable via date selector.
       - **Event Category Selector:**
         - `EventCategory.birthday` (`🎂 Birthday` - Pink badge)
         - `EventCategory.customDate` (`🎯 Milestone / Custom Event` - Blue badge)
       - **Optional Notes:** Multi-line text field for event context.
     - **Storage & State:**
       - Instantiates `ShamsiEvent` with `isCustom: true`, `isOfficialHoliday: false`.
       - Persisted to `StorageService` under `_customEvents` key in `SharedPreferences`.
       - Merged dynamically with `ShamsiEvent.defaultEvents` for real-time agenda and calendar rendering.
     - **Deletion Support:** Custom events retain the trash icon on their badge in the daily list to allow instant deletion.

#### 8.2.1.1 Centered Top Bar Date and Centered Action Buttons with Dynamic Responsive Spacing
- **Problem Statement:** In the top banner of `ShamsiAgendaBanner`, the date badge was pinned to the left and action buttons (`+ Event`, `🗓️ Pick Date`, `📅 Calendar`) were aligned to the right. On narrow mobile viewports (such as the Samsung Galaxy A12 at 360dp logical width), this asymmetrical layout caused awkward multi-line wrapping and left-right visual imbalance. Additionally, the action buttons lacked the dynamic, proportional spacing featured in the quick date navigation bar below them (`« Month`, `‹ Week`, `‹ Day`, `Today`, etc.).
- **Architectural Solution:**
  1. **Horizontally Centered Date Display:**
     - The day number, month/year title, weekday, and Gregorian conversion are wrapped in a horizontally centered column (`CrossAxisAlignment.center` with `MainAxisAlignment.center`).
     - Aligns the visual focal point of the daily agenda directly along the vertical center axis of the screen for balanced symmetry.
  2. **Centered Action Buttons Row with Dynamic Responsive Spacing:**
     - The three action buttons (`+ Event`, `🗓️ Pick Date`, `📅 Calendar`) are grouped into a dedicated row centered horizontally directly beneath the date display.
     - Modeled directly after the quick navigation bar: wrapped in `LayoutBuilder` with `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.center)` and `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly)`:
       ```dart
       LayoutBuilder(
         builder: (context, constraints) {
           return FittedBox(
             fit: BoxFit.scaleDown,
             alignment: Alignment.center,
             child: ConstrainedBox(
               constraints: BoxConstraints(minWidth: constraints.maxWidth),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                 children: [
                   if (widget.onAddCustomEvent != null) _buildAddEventButton(),
                   _buildPickDateButton(),
                   _buildToggleCalendarButton(),
                 ],
               ),
             ),
           );
         },
       )
       ```
     - On narrow mobile devices (360dp), `FittedBox` smoothly scales down button padding and font metrics without any horizontal clipping or overflow exceptions, while desktop and tablet viewports enjoy balanced, evenly distributed spacing.

#### 8.2.2 Dynamic Calendar Dot Colors by Event Priority & Type
- **Problem Statement:** In the Shamsi month calendar grid, every day containing an event currently displays an identical amber dot (`Color(0xFFF59E0B)`), providing no visual distinction between routine official holidays, personal milestones, and birthdays.
- **Architectural Solution:**
  1. **Color Mapping Matrix:**
     | Event Category | Hex Code | Purpose / Distinction | Dot Rendering Priority |
     | :--- | :--- | :--- | :--- |
     | **Birthday** (`birthday`) | `#EC4899` / `#F472B6` | Personal Birthdays | **Priority 1 (Highest)** |
     | **Custom Date** (`customDate`) | `#60A5FA` / `#93C5FD` | Custom Events & Deadlines | **Priority 2** |
     | **Official Holiday** (`holiday`) | `#F59E0B` / `#FBBF24` | Iranian Solar Hijri Holidays | **Priority 3 (Default)** |

  2. **Dynamic Dot Resolution Logic (`ShamsiAgendaBanner`):**
     - For each day cell in the month grid (`GridView.builder`):
       ```dart
       Color? _resolveDotColor(int month, int day) {
         final dayEvents = widget.events.where(
           (e) => e.isEnabled && e.jalaliMonth == month && e.jalaliDay == day,
         ).toList();

         if (dayEvents.isEmpty) return null;

         // Priority 1: User Birthdays (Pink)
         if (dayEvents.any((e) => e.category == EventCategory.birthday)) {
           return const Color(0xFFEC4899);
         }
         // Priority 2: User Custom Milestones/Events (Blue)
         if (dayEvents.any((e) => e.category == EventCategory.customDate)) {
           return const Color(0xFF60A5FA);
         }
         // Priority 3: Default Official Holiday (Orange)
         return const Color(0xFFF59E0B);
       }
       ```
  3. **Visual Representation:**
     - The circular dot indicator (radius 4dp) at the bottom of the date cell dynamically paints with `_resolveDotColor(month, day)`. If a day has both a national holiday and a friend's birthday, the dot renders in vibrant pink, immediately drawing the user's focus to their personal event.

#### 8.2.3 "Postpone" Action Button & Shamsi Date Postponement Engine
- **Problem Statement:** The execution action button for shifting tasks was previously labeled `"Tomorrow"`. Furthermore, when a task was postponed, a separate secondary text box reading `"Postponed (1x)"` or `"Postponed (2x)"` rendered inside the card action row. This text box consumed horizontal space, caused button overflow on narrow displays, and created redundant visual noise.
- **Architectural Solution:**
  1. **Button Renaming:**
     - The button is renamed from `"Tomorrow"` to **`"Postpone"`**.
  2. **Dynamic Multiplier Counter on Button Label:**
     - If `task.postponedCount == 0`: Button label displays `'Postpone'`.
     - If `task.postponedCount == 1`: Button label displays `'Postpone'` with an active amber background/accent glow to indicate it is currently in a postponed state.
     - If `task.postponedCount >= 2`: The multiplier is embedded directly into the button label: `'Postpone 2x'`, `'Postpone 3x'`, `'Postpone 4x'`, etc.:
       ```dart
       String get postponeButtonLabel {
         if (task.postponedCount >= 2) {
           return 'Postpone ${task.postponedCount}x';
         }
         return 'Postpone';
       }
       ```
  3. **Complete Elimination of Separate "Postponed (1x)" Text Box:**
     - The standalone `Text('Postponed (${task.postponedCount}x)')` container is removed entirely from `TaskCard`.
     - Postponement status and repetition count are consolidated cleanly into the `"Postpone"` button itself, preserving clean horizontal layout for task execution and linked media goals.
  4. **Gesture Controls & Date Picker Sub-Menu Workflow:**
     - **Quick Tap:** Immediately postpones the task to tomorrow (`currentDate + 1 day`), increments `postponedCount`, sets `status = TaskStatus.postponed`, and updates `StorageService`.
     - **Long Press (Hold):** Directly triggers the clean Shamsi date picker sub-menu modal without displaying any text input prompt:
       ```
       [User Holds "Postpone" Button]
                  │
                  ▼
       ┌────────────────────────────────────────────────────────┐
       │ 📅 Reschedule Task Date                                │
       │ Choose target Shamsi date for "[Task Title]":          │
       │                                                        │
       │   [ +1 Day (Tomorrow) ]     [ +2 Days ]                │
       │   [ +1 Week           ]     [ Next Month ]             │
       │                                                        │
       │   ─── OR ───                                           │
       │   [ 🗓️ Open Shamsi Date Picker Dialog ]               │
       └────────────────────────────────────────────────────────┘
                  │
                  ▼
       [Target Shamsi Date Selected]
                  │
                  ▼
       • Updates task.targetDateJalali
       • Increments task.postponedCount (+1)
       • Sets task.status = TaskStatus.postponed
       • Saves to StorageService immediately with 0 text prompt
       ```

#### 8.2.4 Compact Mini-Tasks & Vertically Centered Left Reorder Handle

##### 8.2.4.1 Conditional Mini-Task Layout
- **Problem Statement:** When tasks do not have notes/descriptions (e.g. quick checklist items like *"Call bank"* or *"Water plants"*), `TaskCard` renders blank vertical space, dividers, and padding suited for multi-line notes, causing excessive scrolling.
- **Architectural Solution:**
  - When `task.notes.trim().isEmpty`:
    - Vertical card padding reduced from `12dp` to `8dp`.
    - Eliminate bottom notes container completely.
    - Reduce divider spacing: change `SizedBox(height: 8)` to `SizedBox(height: 4)`.
    - Compact action button row padding.

##### 8.2.4.2 Vertically Centered Left Reorder Handle
- **Problem Statement:** In previous iterations, the reorder drag handle (`Icons.drag_indicator`) was nested inside the top row alongside the task title with top padding (`padding: EdgeInsets.only(top: 2, right: 8)`). When a card had multiple lines of title, notes, or media goal badges, the drag handle remained pinned to the upper-left corner, feeling detached from the card's center of mass.
- **Architectural Solution:**
  - Maintain the handle's location strictly on the **left side** of the card.
  - Vertically center the drag handle across the card's full height using `CrossAxisAlignment.center`:
    ```dart
    Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (dragIndex != null)
          ReorderableDragStartListener(
            index: dragIndex!,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_indicator, size: 20, color: palette.textDim),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Linked media goal badge (if attached)
              // Title row with RTL detection
              // Notes (if present)
              // Execution buttons row (Done, Postpone, Cancel)
            ],
          ),
        ),
      ],
    )
    ```
  - **Visual Hierarchy Comparison:**
    ```
    Standard Task (With Notes & Vertically Centered Handle):
    ┌──────────────────────────────────────────────────────────┐
    │    ┌─ [Task Title]                                   ✕ ─┐│
    │ ≡  │  Multi-line personal description and notes here... ││
    │    │  ───────────────────────────────────────────       ││
    │    └─ [Done] [Postpone 2x] [Cancel]          ⚡ Schedule ┘│
    └──────────────────────────────────────────────────────────┘

    Compact Mini-Task (No Notes & Vertically Centered Handle):
    ┌──────────────────────────────────────────────────────────┐
    │ ≡  ┌─ [Task Title]                                   ✕ ─┐│
    │    └─ [Done] [Postpone] [Cancel]             ⚡ Schedule ┘│
    └──────────────────────────────────────────────────────────┘
    ```

#### 8.2.5 Auto-Scroll on Task Reordering Near Viewport Top/Bottom Boundaries
- **Problem Statement:** When reordering tasks using `ReorderableListView.builder`, the list is nested inside a parent `SingleChildScrollView` with `NeverScrollableScrollPhysics`. When dragging a task toward the top or bottom of the screen, the list fails to auto-scroll, trapping the dragged task within the visible viewport bounds.
- **Architectural Solution:**
  1. **Scroll Proximity Auto-Scroll Controller (`main.dart`):**
     - Attach a dedicated `ScrollController` to the root scroll view.
     - Implement boundary coordinate monitoring:
       - When dragging starts (`onReorderStart`), initiate a periodic tick timer (every 50ms).
       - Track the global Y position of the active drag pointer.
       - **Top Threshold (within 90dp of viewport top):** Auto-scroll up at a rate proportional to distance from the top edge:
         ```dart
         final delta = (90.0 - pointerY).clamp(0.0, 90.0) / 90.0 * 16.0;
         scrollController.jumpTo((scrollController.offset - delta).clamp(0.0, maxScroll));
         ```
       - **Bottom Threshold (within 90dp of viewport bottom):** Auto-scroll down smoothly:
         ```dart
         final delta = (pointerY - (screenHeight - 90.0)).clamp(0.0, 90.0) / 90.0 * 16.0;
         scrollController.jumpTo((scrollController.offset + delta).clamp(0.0, maxScroll));
         ```
       - When dragging completes (`onReorder`), cancel the auto-scroll timer cleanly.

#### 8.2.6 Colors Rework & Theme Harmonization

##### 8.2.6.1 Merge Persian Turquoise Background into Nordic Slate & Eliminate Persian Turquoise
- **User Directive:** Merge the deep dark background colors of Persian Turquoise with the luminous icy foreground colors of Nordic Slate, and remove Persian Turquoise entirely so that only Nordic Slate remains.
- **Architectural Solution:**
  1. **Nordic Slate Palette Update (`minimalNordic`):**
     - Adopts Persian Turquoise's deep nocturnal teal background tones:
       - `bgCanvas`: `Color(0xFF091319)` (Deep Teal Abyss)
       - `bgSurface`: `Color(0xFF0F1F28)` (Nocturnal Slate Surface)
       - `bgElevated`: `Color(0xFF162D3A)` (Elevated Teal Charcoal)
     - Preserves Nordic Slate's signature Scandinavian icy sky foreground accents:
       - `accentPrimary`: `Color(0xFF38BDF8)` (Vibrant Ice Sky)
       - `textMain`: `Color(0xFFF0F9FF)` (Crisp Glacial White)
       - `textMuted`: `Color(0xFF7DD3FC)` (Soft Polar Cyan)
       - `textDim`: `Color(0xFF0284C7)` (Deep Arctic Blue)
       - `accentGradient`: `LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)])` (Aurora Borealis glow)
  2. **Removal of Persian Turquoise:**
     - Delete `ThemeVibe.persianTurquoise` from `enum ThemeVibe`.
     - Remove the `persianTurquoise` entry from `AppTheme.vibes` map and `SettingsDrawer`.
     - Any user settings referencing `persianTurquoise` fallback automatically to `minimalNordic`.

##### 8.2.6.2 Revitalize Bland & Generic Color Palettes
The palettes are revitalized with rich saturated canvases, luminous borders, and distinctive accents:

| Theme Enum | Label | Background Canvas (`bgCanvas`) | Surface (`bgSurface`) | Elevated (`bgElevated`) | Accent Primary (`accentPrimary`) | Accent Gradient Colors | Design Aesthetic |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `emeraldCyan` | **Emerald Cyan** | `#051311` (Deep Jade) | `#0B201D` | `#13302C` | `#10B981` (Vibrant Mint) | `[#059669, #10B981, #06B6D4]` | Luminous emerald rainforest with cyan water glow. |
| `minimalNordic` | **Nordic Slate** | `#091319` (Persian Teal Canvas) | `#0F1F28` | `#162D3A` | `#38BDF8` (Ice Sky) | `[#38BDF8, #818CF8, #C084FC]` | Consolidated Persian Teal abyss with Scandinavian frozen aurora. |
| `arcticFrost` | **Arctic Frost** | `#070F1E` (Polar Deep) | `#0D192E` | `#152542` | `#7DD3FC` (Neon Frost) | `[#E0F2FE, #7DD3FC, #38BDF8]` | Sub-zero polar ice with crystalline luminescent glow. |
| `sunsetAmber` | **Sunset Amber** | `#180D0B` (Volcanic Twilight)| `#251512` | `#351E1A` | `#F97316` (Blazing Tangerine)| `[#EA580C, #F97316, #FB7185]` | Warm volcanic dusk embers with coral rose highlights. |
| `cyberViolet` | **Cyber Violet** | `#0D071E` (Synthwave Void) | `#170D31` | `#231448` | `#D946EF` (Electric Fuchsia)| `[#A855F7, #D946EF, #06B6D4]` | Outrun / Cyberpunk neon magenta & electric violet. |

##### 8.2.6.3 Purple Themes Consolidation: Remove Deep Lavender & Deepen Deep Amethyst
- **User Directive:** Remove Deep Lavender entirely and make Deep Amethyst deeper to achieve high-contrasted blacks and a more bold purple.
- **Architectural Solution:**
  1. **Complete Removal of Deep Lavender (`ThemeVibe.electricLavender`):**
     - Remove `electricLavender` from `enum ThemeVibe`, palette maps, and drawer selections.
  2. **Deepening Deep Amethyst (`ThemeVibe.deepAmethyst`):**
     - Canvas and surfaces are driven to abyssal, pitch-black plum tones to maximize contrast:
       - `bgCanvas`: `Color(0xFF05020A)` (Pure Abyssal Black Plum)
       - `bgSurface`: `Color(0xFF0F0419)` (Nocturnal Obsidian Violet)
       - `bgElevated`: `Color(0xFF1B072D)` (Midnight Amethyst Velvet)
       - `borderSubtle`: `Color(0x35B026FF)`
       - `borderFocus`: `Color(0x80B026FF)`
     - Text typography optimized for extreme readability against pitch black:
       - `textMain`: `Color(0xFFFAF5FF)` (Crisp high-contrast ice white)
       - `textMuted`: `Color(0xFFE9D5FF)` (Soft radiant lilac)
       - `textDim`: `Color(0xFFA855F7)` (Luminescent violet)
     - Accents electrified with bold, saturated jewel purple:
       - `accentPrimary`: `Color(0xFFB026FF)` (Bold High-Voltage Royal Jewel Purple)
       - `accentGradient`: `LinearGradient(colors: [Color(0xFF7E22CE), Color(0xFFB026FF), Color(0xFFD946EF)])`
  3. **The 3 Purple Theme Lineup:**
     ```
     ┌────────────────────────────────────────────────────────────────────────────────────────┐
     │                              THE 3 PURPLE THEME IDENTITIES                             │
     ├─────────────────────────────┬───────────────────────────┬──────────────────────────────┤
     │        DEEP AMETHYST        │       PURPLE & GOLD       │       PURPLE & ORANGE        │
     ├─────────────────────────────┼───────────────────────────┼──────────────────────────────┤
     │ • Abyssal black-plum canvas │ • Pure onyx black canvas  │ • Midnight plum canvas       │
     │   (#05020A)                 │   (#08040C)               │   (#12061A)                  │
     │ • High-contrast pitch black │ • Radiant 24k gold        │ • Electric neon tangerine    │
     │   surfaces (#0F0419)        │   primary (#F59E0B)       │   primary (#FF6B00)          │
     │ • Bold royal jewel purple   │ • High-contrast regal     │ • High-voltage clashing warm │
     │   accent (#B026FF)          │   gold trims              │   contrast                   │
     └─────────────────────────────┴───────────────────────────┴──────────────────────────────┘
     ```
     1. **Deep Amethyst (`deepAmethyst`):** `bgCanvas`: `#05020A` | `bgSurface`: `#0F0419` | `bgElevated`: `#1B072D` | `accentPrimary`: `#B026FF` | `accentGradient`: `[#7E22CE, #B026FF, #D946EF]`
     2. **Purple & Gold (`imperialGold`):** `bgCanvas`: `#08040C` | `bgSurface`: `#140A1E` | `bgElevated`: `#211030` | `accentPrimary`: `#F59E0B` | `accentGradient`: `[#D97706, #F59E0B, #FDE047]`
     3. **Purple & Orange (`purpleOrange`):** `bgCanvas`: `#12061A` | `bgSurface`: `#1F0A2C` | `bgElevated`: `#2F1042` | `accentPrimary`: `#FF6B00` | `accentGradient`: `[#9333EA, #FF6B00, #FFAA00]`

#### 8.2.7 Native RTL Detection for Persian Tasks & Dynamic Input Directionality
- **Problem Statement:** When Persian/Farsi task titles or notes are entered, they default to Left-to-Right (LTR) alignment, resulting in awkward punctuation positioning and inverted sentence flow. Additionally, input text fields do not switch directionality as the user types in Persian.
- **Architectural Solution:**
  1. **RTL Detection Utility (`lib/services/rtl_detection_service.dart`):**
     ```dart
     class RtlDetectionService {
       // Perso-Arabic unicode ranges: Arabic, Persian, Arabic Supplement, Extended-A
       static final RegExp _persianArabicRegex = RegExp(
         r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
       );

       /// Returns true if the first non-whitespace character is Persian/Arabic.
       static bool startsWithRtl(String text) {
         final trimmed = text.trimLeft();
         if (trimmed.isEmpty) return false;
         return _persianArabicRegex.hasMatch(trimmed[0]);
       }

       /// Resolves TextDirection based on content leading script.
       static TextDirection resolveDirection(String text) {
         return startsWithRtl(text) ? TextDirection.rtl : TextDirection.ltr;
       }

       /// Resolves TextAlign based on content leading script.
       static TextAlign resolveAlignment(String text) {
         return startsWithRtl(text) ? TextAlign.right : TextAlign.left;
       }
     }
     ```
  2. **Task Display Integration (`TaskCard`):**
     - Task Title:
       ```dart
       Text(
         task.title,
         textDirection: RtlDetectionService.resolveDirection(task.title),
         textAlign: RtlDetectionService.resolveAlignment(task.title),
         style: titleStyle,
       )
       ```
     - Task Notes:
       ```dart
       Text(
         task.notes,
         textDirection: RtlDetectionService.resolveDirection(task.notes),
         textAlign: RtlDetectionService.resolveAlignment(task.notes),
         style: notesStyle,
       )
       ```
  3. **Dynamic Input Field Directionality (`main.dart`):**
     - In the "Add Task" and "Edit Task" dialogs:
       - Attach a listener to `titleController` and `notesController`:
         ```dart
         ValueNotifier<TextDirection> _titleDirection = ValueNotifier(TextDirection.ltr);

         titleController.addListener(() {
           final dir = RtlDetectionService.resolveDirection(titleController.text);
           if (_titleDirection.value != dir) {
             _titleDirection.value = dir;
           }
         });
         ```
       - Bind `TextField.textDirection` dynamically via `ValueListenableBuilder`. When the user types the first Persian character (e.g. "خ"), the cursor and text alignment instantly flip to the right-hand side (RTL). If typing English (e.g. "B"), it stays LTR.

#### 8.2.8 3-Second Long Press on Task Card for Editing (with Mini-Task Adaptation)
- **Problem Statement:** Users need an intuitive gesture on the task card itself to open the edit dialog for changing the title and description. When a mini-task (which had no description) receives a description, the UI must dynamically transition without clipping.
- **Architectural Solution:**
  1. **3-Second Gesture Detector (`TaskCard`):**
     - Wrap the card container in a dedicated gesture detector:
       ```dart
       GestureDetector(
         onLongPress: () {
           // Triggers after hold threshold (configured to standard long press or custom 3s timer)
           onEditTask();
         },
         child: ...
       )
       ```
     - Optional haptic feedback (`HapticFeedback.mediumImpact()`) on trigger.
  2. **Unified Edit Modal (`_showEditTaskDialog` in `main.dart`):**
     - Pre-fills `titleController` and `notesController`.
     - Supports Sentence Case and dynamic RTL detection.
  3. **Dynamic Mini-Task Expansion:**
     - When saving an edit where `oldNotes.isEmpty` and `newNotes.isNotEmpty`:
       - The task state updates seamlessly.
       - `TaskCard` immediately detects `task.notes.isNotEmpty`, expanding to render the notes section with proper padding and dividers without layout jitter or rebuild errors.

#### 8.2.9 Automatic Down-Listing for Completed ("Done") Tasks
- **Problem Statement:** When tasks were checked off as completed (`Done`), they previously maintained their static `orderIndex` and remained in the middle of active items. This mixed finished tasks with pending tasks, forcing the user to mentally filter the list and allowing completed tasks to obstruct high-priority pending items.
- **Architectural Solution:**
  1. **Dynamic Task Sorting Rule (`DateNavigationService` & `main.dart`):**
     - Task streams in both Today's Focus (`_dailyTasks`) and Orbit & Backlog (`_backlogTasks`) enforce a status partition comparator:
       ```dart
       int compareTaskExecutionState(Task a, Task b) {
         final aDone = a.status == TaskStatus.completed;
         final bDone = b.status == TaskStatus.completed;

         // Completed tasks sink to the bottom; active/pending/postponed tasks stay at the top
         if (aDone != bDone) {
           return aDone ? 1 : -1;
         }
         return a.orderIndex.compareTo(b.orderIndex);
       }
       ```
  2. **Reactive Execution Flow:**
     - Tapping `[Done]` immediately updates `task.status = TaskStatus.completed`.
     - The task list smoothly re-renders with the completed task positioned at the bottom of the list.
     - Tapping `[Done]` again toggles status back to `pending`, smoothly restoring the task to its designated place among the active tasks at the top.
  3. **Reordering Preservation:**
     - User drag reordering operates independently within the active tasks group or within the completed tasks group without scrambling status separation.

#### 8.2.10 Collapsible / Minimizable Task Lists (Today's Focus & Backlog) with Arrow-Only Controls
- **Problem Statement:** When either Today's Focus or Orbit & Backlog contains many tasks, the entire screen becomes vertically crowded. Users need a quick, minimal mechanism to minimize/collapse either section so they can focus on the active stream without excessive scrolling.
- **Design Constraint:** The toggle control must be minimalist and clean: **strictly an arrow icon without verbose text labels** (no "Collapse", "Expand", or "Show/Hide" text).
- **Architectural Solution:**
  1. **State Flags:**
     ```dart
     bool _isDailyFocusCollapsed = false;
     bool _isBacklogCollapsed = false;
     ```
  2. **Arrow-Only Icon Button Header Integration:**
     - Place an icon button immediately adjacent to the section title:
       ```dart
       InkWell(
         onTap: () => setState(() => _isDailyFocusCollapsed = !_isDailyFocusCollapsed),
         borderRadius: BorderRadius.circular(6),
         child: Padding(
           padding: const EdgeInsets.all(4),
           child: Icon(
             _isDailyFocusCollapsed
                 ? Icons.keyboard_arrow_down
                 : Icons.keyboard_arrow_up,
             size: 20,
             color: _palette.accentPrimary,
           ),
         ),
       )
       ```
  3. **Animated Body Collapsing:**
     - Wrap the `ReorderableListView` in an `AnimatedCrossFade` or conditional layout:
       - When `_isDailyFocusCollapsed == true`: The task list and empty state container collapse to `SizedBox.shrink()`.
       - When `_isDailyFocusCollapsed == false`: The full task list renders with normal drag-and-drop handles.
     - **Header Retention:** When minimized, the section header remains fully visible, showing the section title, arrow button, completion counters (`4/6 Done`), and the themed progress bar.

#### 8.2.11 Task Status Breakdown Counters & Dynamic Theme-Colored Progress Bar
- **Problem Statement:** Task section headers previously displayed only a generic total count (e.g. `[ 5 ]`), offering no breakdown of finished vs. canceled tasks, and no visual feedback indicating daily momentum or milestone progress.
- **Architectural Solution:**
  1. **Detailed Task Status Breakdown:**
     - Compute real-time status tallies for the stream:
       ```dart
       final total = tasks.length;
       final doneCount = tasks.where((t) => t.status == TaskStatus.completed).length;
       final canceledCount = tasks.where((t) => t.status == TaskStatus.canceled).length;
       final pendingCount = total - doneCount - canceledCount;
       ```
     - **Header Counter Badges:**
       - **Done Ratio Badge:** Renders `$doneCount/$total Done` (e.g. `4/6 Done`) in a high-contrast pill with bold typography (`palette.accentPrimary` or vibrant green when `doneCount == total`).
       - **Canceled Badge:** If `canceledCount > 0`, renders a subtle muted badge beside it (`• $canceledCount canceled` in `palette.textDim`), providing a transparent breakdown without cluttering the title.
  2. **Dynamic Theme-Colored Linear Progress Bar:**
     - Positioned immediately beneath the section header row:
       ```dart
       // Completion percentage: 0.0 to 1.0
       final progress = total == 0 ? 0.0 : (doneCount / total).clamp(0.0, 1.0);

       Container(
         margin: const EdgeInsets.only(top: 8, bottom: 4),
         height: 5,
         decoration: BoxDecoration(
           color: _palette.bgElevated,
           borderRadius: BorderRadius.circular(4),
           border: Border.all(color: _palette.borderSubtle),
         ),
         child: FractionallySizedBox(
           alignment: Alignment.centerLeft,
           widthFactor: progress,
           child: Container(
             decoration: BoxDecoration(
               gradient: _palette.accentGradient,
               borderRadius: BorderRadius.circular(4),
               boxShadow: [
                 BoxShadow(
                   color: _palette.accentGlow,
                   blurRadius: 4,
                   offset: const Offset(0, 1),
                 ),
               ],
             ),
           ),
         ),
       )
       ```
     - **Theme Reactivity:** The progress bar shader gradient (`_palette.accentGradient`) and glow shadow (`_palette.accentGlow`) change automatically whenever the user switches the active theme vibe (Nordic Slate, Deep Amethyst, Arctic Frost, Sunset Amber, etc.), providing instant aesthetic harmonization across all streams.

---

### 8.3 Entertainment Ledger Improvements

#### 8.3.1 Persistent Cover Art Disk Caching System
- **Problem Statement:** Currently, `SafeCoverImage` uses `Image.network`. Each time the application is closed or memory is reclaimed on Android, poster covers must be re-downloaded over the network, wasting mobile data and causing image flicker.
- **Architectural Solution:**
  1. **Dependency Integration:**
     - Integrate `cached_network_image: ^3.4.1` into `pubspec.yaml`.
  2. **Resilient Disk Cache Pipeline (`SafeCoverImage`):**
     ```dart
     CachedNetworkImage(
       imageUrl: effectiveUrl,
       fit: fit,
       memCacheWidth: cacheWidth,
       memCacheHeight: cacheHeight,
       placeholder: (context, url) => Container(
         color: palette.bgElevated,
         child: const Center(
           child: SizedBox(
             width: 18,
             height: 18,
             child: CircularProgressIndicator(strokeWidth: 2),
           ),
         ),
       ),
       errorWidget: (context, url, error) {
         // Fallback via CORS / Weserv Proxy with caching
         return CachedNetworkImage(
           imageUrl: toCorsProxyUrl(cleanUrl),
           fit: fit,
           errorWidget: (ctx, err, st) => _buildInitialsFallback(),
         );
       },
     )
     ```
  3. **Performance Contract:**
     - Once downloaded, artwork binary files are saved directly into the application's local cache directory on device flash storage.
     - Covers load with **zero latency (0ms)** on subsequent application launches, even when offline.

#### 8.3.2 Desaturated "Enter Notes" Description Placeholder
- **Problem Statement:** In the Entertainment ledger, the description placeholder text (`"Enter notes"` / `"+ Add personal description/notes..."`) uses high-saturation text styling, making placeholders look like active user notes.
- **Architectural Solution:**
  1. **Typography & Opacity Adjustment (`MediaCard` & Edit Modal):**
     - Update placeholder color to a desaturated, muted tone (`palette.textDim` with reduced opacity):
       ```dart
       TextStyle(
         fontSize: 12,
         fontStyle: FontStyle.italic,
         color: palette.textDim.withValues(alpha: 0.45),
       )
       ```
  2. **Dialog `InputDecoration`:**
     - Set `hintStyle: TextStyle(color: palette.textDim.withValues(alpha: 0.45))` for the notes input field.
     - Provides clear visual distinction between empty placeholder guidance and user-entered notes.

#### 8.3.3 Modernized Label Sub-Menu Architecture: Compact Space-Filling Buttons, Long-Press Deletion from Database, Removal of `(Custom)` Tagline, and Default Presets ("Fantasy" replacing "Masterpiece")
- **Problem Statement & User Feedback:**
  1. *Inefficient Space Utilization:* The previous sub-menu rendered a single-column `ListView` of `CheckboxListTile` elements. Because each tile occupied an entire vertical row while using minimal horizontal width, users were forced to scroll extensively to view available tags.
  2. *Label Taglines:* Custom user tags displayed a redundant `(Custom)` tagline, adding clutter and visual inconsistency.
  3. *Immutable Defaults:* Users lacked the ability to remove unwanted default preset labels (e.g. *"Masterpiece"*) or manage their label database freely.
  4. *Outdated Presets:* The default label *"Masterpiece"* is subjective and less useful than common genre categorizations like *"Fantasy"*.
- **Architectural Solution:**
  1. **Default Preset List Overhaul (`MediaLabelService.presetLabels`):**
     - Remove `'Masterpiece'` from default presets.
     - Add `'Fantasy'` to default presets.
     - Standard default preset list:
       ```dart
       static const List<String> presetLabels = [
         'Sci-Fi',
         'Drama',
         'Horror',
         'Fantasy',
         'RPG',
         'Ongoing',
       ];
       ```
  2. **Space-Filling Compact Button Wrap Layout (Sub-Menu Bottom Sheet):**
     - The sub-menu dialog / modal bottom sheet replaces the single-column vertical `CheckboxListTile` list with a responsive, multi-row **`Wrap` layout of compact small buttons**:
       ```dart
       Wrap(
         spacing: 8,
         runSpacing: 8,
         children: availableLabels.map((tag) {
           final isSelected = selectedLabels.contains(tag);
           return InkWell(
             onTap: () => _toggleTagSelection(tag),
             onLongPress: () => _confirmRemoveLabelFromDatabase(tag),
             borderRadius: BorderRadius.circular(8),
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
               decoration: BoxDecoration(
                 color: isSelected ? palette.accentPrimary : palette.bgElevated,
                 border: Border.all(
                   color: isSelected ? palette.accentPrimary : palette.borderSubtle,
                 ),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Text(
                 tag,
                 style: TextStyle(
                   fontSize: 12,
                   fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                   color: isSelected ? Colors.black : palette.textMain,
                 ),
               ),
             ),
           );
         }).toList(),
       )
       ```
     - **Ergonomic Advantages:** Utilizing the entire horizontal and vertical space of the sub-menu allows dozens of tags to be viewed and tapped simultaneously without continuous scrolling.
  3. **Universal Tag Treatment (Elimination of `(Custom)` Tagline):**
     - All tags are rendered cleanly and uniformly by name only (e.g. `[Sci-Fi]`, `[Fantasy]`, `[Cyberpunk]`).
     - Eliminates visual clutter and treats all labels with equal structural priority.
  4. **Long-Press to Remove Entirely from Database (Default & Custom Tags):**
     - Pressing and holding (Long Press) on any label button in the sub-menu triggers a deletion confirmation dialog:
       - *"Remove '[tag]' permanently from the labels database? This will also remove it from any media items currently using it."*
     - Confirming deletes the label from the active label database, strips it from any tagged `MediaItem` instances, and updates `StorageService`.
     - **Full Customizability:** Users can delete both custom-created tags AND default preset tags (e.g. deleting *"Horror"* if the user never tracks horror media).
  5. **Persistence of Active Label Database (`StorageService`):**
     - Persists the active list of labels in `SharedPreferences` under key `_activeLabelsKey`.
     - Defaults to `MediaLabelService.presetLabels` on first install. Any user addition or long-press deletion is persisted across app launches.

#### 8.3.4 3-Second Long Press on Media Tiles to Open Full Edit Modal
- **Problem Statement:** Currently, editing various properties of a media item requires multiple fragmented interactions: tapping the cover opens cover editing, tapping labels opens label editing, tapping notes opens notes editing, and updating progress has its own dialog. There is no unified gesture on the media tile itself to open a comprehensive edit dialog.
- **Architectural Solution:**
  1. **3-Second Gesture Integration (`lib/widgets/media_card.dart`):**
     - Both List View (`_buildListCard`) and Grid View (`_buildGridCard`) root containers are wrapped in a `GestureDetector`:
       ```dart
       GestureDetector(
         onLongPress: () {
           HapticFeedback.mediumImpact();
           onEditMedia();
         },
         child: ...
       )
       ```
     - Emits tactile feedback and triggers the centralized callback `onEditMedia`.
  2. **Centralized Media Edit Modal (`_showEditMediaDialog` in `main.dart`):**
     - A single, cohesive dialog consolidating all media parameters:
       - **Title:** Sentence case text input with dynamic Persian RTL auto-detection.
       - **Release Year:** Numeric text field.
       - **Description / Personal Notes:** Multi-line text field with desaturated hint text.
       - **Cover Image:** Poster thumbnail preview, sanitized URL input, and `🔍 Auto-Fetch Cover` integration.
       - **Metric Units & Capacity:** Target goal and total capacity numbers (enforcing validation `current <= total`).
       - **Labels & Tags:** Button opening the unified `LabelSelectionModal`.
       - **Half-Point Rating:** Interactive star/slider control (1.0 to 10.0).
       - **On-Hold Toggle:** Switch to mark the item as on hold or active.
       - **Remove Media Button:** Quick access to the deletion workflow with confirmation.
  3. **Display Parity & State Persistence:**
     - Operates identically whether the user is in List View or 2-column Grid View.
     - Saving changes updates the `MediaItem` in `_mediaItems`, automatically recalculating linked task titles (e.g. `🎯 Media Goal: [New Title]`), and persists immediately to `StorageService.saveMediaItems(_mediaItems)`.

#### 8.3.5 Chronological Media Sorting: Renaming "Custom Order" to "Recently Added"
- **Problem Statement & Terminology Comparison:**
  - The default entertainment ledger sorting option was previously labeled `"Custom Order"`. This label is confusing because manual drag reordering is not the primary mode of browsing media ledgers.
  - When comparing the two candidate names:
    - **"Date Added":** Functional, but somewhat static and technical.
    - **"Recently Added":** **Selected as the optimal term.** In digital entertainment cataloging (Apple Music, Steam Library, Plex, Spotify, Goodreads), *"Recently Added"* is the universal industry standard. It immediately communicates that the newest media entries appear at the top of the collection, reflecting the user's ongoing entertainment journey.
- **Architectural Solution:**
  1. **Dropdown Menu Update (`main.dart`):**
     - Replace `'Custom Order'` label with `'Recently Added'`:
       ```dart
       DropdownMenuItem(
         value: 'custom',
         child: Text('Recently Added'),
       ),
       ```
  2. **Sorting Logic (`_filteredMediaItems`):**
     - When `_mediaSort == 'custom'` (Recently Added):
       - Sorts items by `createdAt` descending: `list.sort((a, b) => b.createdAt.compareTo(a.createdAt));`
       - Newly added movies, games, books, and TV shows appear prominently at the top of the ledger.

#### 8.3.6 Multi-Platform & Console Video Game Cover Architecture: Nintendo Switch, PlayStation, Xbox, and Retro Systems
- **System Inquiry & Scope Analysis:**
  - *Is the cover source of video games Steam? What about Nintendo and other console games?*
  - **Current Implementation Reality:** Yes, the current `CoverFetchService._searchGames` queries exclusively the **Steam Store Search API** (`store.steampowered.com/api/storesearch`) with a **CheapShark API** fallback (which also queries Steam App IDs).
  - **The Console Gap:** Because Steam exclusively distributes PC games, searches for console exclusives (e.g. Nintendo Switch's *The Legend of Zelda: Tears of the Kingdom*, *Super Mario Odyssey*, *Pokémon Scarlet/Violet*, *Super Smash Bros. Ultimate*, *Metroid Dread*; PlayStation exclusives like *Bloodborne*, *The Last of Us Part II*, *Demon's Souls*, *God of War: Ragnarök*; and retro console games across NES, SNES, N64, Game Boy, PS1, Xbox 360) return **0 results** on Steam.
- **Multi-Platform Console Architecture Solution:**
  1. **Multi-Source Cover Fetching Pipeline:**
     ```
     [User Searches Video Game Title]
                     │
                     ▼
     ┌──────────────────────────────────────────────┐
     │ 1. Steam Store Search API (PC Games)         │
     └──────────────────────────────────────────────┘
                     │ (If results found -> Return vertical 600x900 poster)
                     │ (If 0 results or query is console-exclusive)
                     ▼
     ┌──────────────────────────────────────────────┐
     │ 2. RAWG Video Games Database API             │
     │    Endpoint: https://api.rawg.io/api/games   │
     │    Coverage: 500,000+ games across 50+       │
     │              platforms (Nintendo, PS, Xbox)  │
     └──────────────────────────────────────────────┘
                     │ (If results found -> Return background_image / boxart)
                     │ (If fallback needed)
                     ▼
     ┌──────────────────────────────────────────────┐
     │ 3. LaunchBox Games Database Open Archive     │
     │    Comprehensive vertical physical box art   │
     │    for all Nintendo, Sega, Sony, & MS games  │
     └──────────────────────────────────────────────┘
                     │ (If fallback needed)
                     ▼
     ┌──────────────────────────────────────────────┐
     │ 4. Libretro OpenVGDB Boxart CDN              │
     │    Direct raw boxart CDN for retro/Nintendo: │
     │    github.com/libretro-thumbnails/           │
     └──────────────────────────────────────────────┘
                     │ (If all network sources fail)
                     ▼
     ┌──────────────────────────────────────────────┐
     │ 5. SafeCoverImage Initials Placeholder       │
     └──────────────────────────────────────────────┘
     ```
  2. **Console Source Specifications:**
     - **RAWG Video Games Database API:**
       - Free tier endpoint: `https://api.rawg.io/api/games?search={query}&page_size=5&key={api_key}`
       - Directly returns platform tags (`Nintendo Switch`, `PlayStation 5`, `Xbox Series S/X`), release years, and high-resolution official key art.
     - **LaunchBox Games Database:**
       - Dedicated physical front-box artwork endpoint indexed by platform and game title.
     - **Libretro Thumbnails CDN:**
       - High-speed direct image repository organized by platform name (e.g. `Nintendo_-_Nintendo_Switch/Named_Boxarts/{title}.png`).
  3. **Aspect Ratio Standardization (`SafeCoverImage`):**
     - Physical console box art comes in varied aspect ratios (Nintendo Switch is ~1:1.6, DVD/PS4 is ~1:1.4).
     - `SafeCoverImage` enforces a uniform vertical 3:4 aspect ratio with `BoxFit.cover` inside rounded container boundaries (`borderRadius: BorderRadius.circular(8)`), ensuring that all game covers—whether PC Steam digital posters or Nintendo Switch physical box arts—render with crisp, consistent alignment without layout deformation.

---

## 9. Comprehensive Architectural Summary

This version 2.4.0 specification establishes a complete blueprint for future implementation:
- **Clean Cross-Platform Typography:** Complete removal of `Vazirmatn` font asset overhead, standardizing on native system Perso-Arabic rendering.
- **Sentence Case Input Standard:** Consistent sentence-level capitalization across tasks, notes, and media entries.
- **Reintroduced Custom Events & Dynamic Calendar Dots:** Restores `+ Event` creation for personal birthdays and milestones with distinctive pink and blue calendar dot indicators.
- **Top Bar Centering & Responsive Dynamic Spacing:** Shamsi top bar date display and action buttons (`+ Event`, `Pick Date`, `Calendar`) are horizontally centered with responsive dynamic scaling matching the date navigation bar.
- **Postpone Button & Multiplier Counter:** Renames "Tomorrow" to "Postpone", displays dynamic multiplier labels (`Postpone 2x`, `Postpone 3x`) directly on the button, and completely eliminates the separate "Postponed (1x)" text box.
- **Vertically Centered Reorder Handle:** Centers task drag handles vertically on the left side of cards across all card heights.
- **Automatic Task Down-Listing:** Completed (`Done`) tasks automatically sink to the bottom of Today's Focus and Orbit & Backlog lists, keeping pending priorities at the top.
- **Collapsible / Minimizable Task Lists:** Toggled via an arrow icon only (no text labels) on section headers to reduce vertical screen crowding.
- **Task Status Counters & Themed Progress Bar:** Section headers display Total, Done, and Cancelled task counts, paired with a linear progress bar dynamically colored by the active theme palette.
- **Theme Consolidation & Purple Overhaul:** Merges Persian Turquoise background canvas into Nordic Slate and removes Persian Turquoise; removes Deep Lavender; deepens Deep Amethyst with pitch-black surfaces and bold royal jewel purple accents.
- **Modernized Label Sub-Menu:** Dense, space-filling compact button `Wrap` layout replacing single-column checkbox lists; long-press to permanently delete any label from the database; removal of `(Custom)` taglines; deletion of default preset labels; and addition of the `"Fantasy"` default preset replacing `"Masterpiece"`.
- **Chronological Entertainment Sorting:** Renames "Custom Order" to "Recently Added", ordering items by creation timeline.
- **Multi-Platform Console Game Cover Architecture:** Multi-source cover fetching pipeline integrating RAWG, LaunchBox, and Libretro Boxart CDNs to provide complete artwork support for Nintendo Switch and console games alongside Steam PC titles.
