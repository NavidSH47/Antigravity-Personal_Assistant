# Software Design Document (SDD)
## Project: NSH Pulse (Lightweight Personal Assistant & Daily Pulse)

**Document Version:** 2.4.0  
**Target Platforms:** Android (API 26+, optimized for Samsung Galaxy A12 & modern devices), Flutter Web (Chrome), Windows Desktop  
**Repository:** Local git repository initialized (`main`)  
**Status:** Approved Architecture & Specification (Version 2.4.0 Active Backlog)

---

## 1. System Overview & Core Pillars

**NSH Pulse** is a zero-latency, local-first companion unifying daily agenda planning, task execution streams, and entertainment tracking.

### Core Functional Pillars
1. **Contextual Day-Planner & Shamsi Agenda:** Solar Hijri calendar integration, official Iranian holidays, custom user events (birthdays/milestones), dynamic dot indicators, and bilingual Gregorian/Jalali sync.
2. **Dual-Stream Task Engine ("Daily Pulse"):** Split streams ("Today's Focus" vs. "Orbit & Backlog"), 3-state execution (`Done`, `Postpone`, `Cancel`), automatic sinking of completed tasks, collapsible stream sections, dynamic Persian RTL detection, compact mini-tasks, and touch/drag reordering with boundary auto-scroll.
3. **Universal Entertainment Ledger:** Books, TV Shows, Movies, and Video Games with metric progress tracking, half-point ratings (1.0–10.0), persistent offline cover art disk caching, multi-platform cover fetching (Steam + Console/Nintendo APIs), compact label selector sub-menu, and chronological sorting.
4. **Adaptive Aesthetics & Dynamic Typography:** High-contrast Dark Vibe palettes with dynamic theme-colored progress indicators, custom-curated fonts (`Comic Neue`, `Quicksand`, `Fira Code`, `Lora`, and clean system sans), and zero external font asset bloat.

---

## 2. Technical Architecture & File Modification Matrix

| File Path | Component | Current Role & Version 2.4.0 Specification |
| :--- | :--- | :--- |
| `pubspec.yaml` | Manifest | Remove `Vazirmatn` font family; declare `cached_network_image: ^3.4.1` for poster disk caching. |
| `assets/fonts/` | Asset Directory | Remove unused `Vazirmatn-Regular.ttf` and `Vazirmatn-Bold.ttf` binaries. |
| `lib/services/sentence_case_service.dart` | Text Formatting | Enforce sentence-level capitalization (`SentenceCaseTextInputFormatter`) across all inputs. |
| `lib/services/rtl_detection_service.dart` | Typography / Bidi | Auto-detect Perso-Arabic unicode ranges to dynamically flip `TextDirection` (RTL/LTR) for tasks and text inputs. |
| `lib/services/cover_cache_service.dart` | Media Caching | Manage local persistent disk caching for fetched media covers so images are never re-downloaded. |
| `lib/services/cover_fetch_service.dart` | Cover Fetching | Multi-source cover fetching: Steam API for PC games + fallback to RAWG / LaunchBox / Libretro CDNs for Nintendo & console games. |
| `lib/services/media_label_service.dart` | Labels & Tags | 1) Replace default preset `'Masterpiece'` with `'Fantasy'`.<br>2) Provide database deletion methods to permanently remove default and custom labels. |
| `lib/services/storage_service.dart` | Persistence | Persist active label list and custom events in `SharedPreferences` across app restarts. |
| `lib/theme/app_theme.dart` | Palettes & Themes | 1) **Persian/Nordic Consolidation:** Merge Persian Turquoise dark teal background (`#091319`, `#0F1F28`, `#162D3A`) into `Nordic Slate` with icy sky foreground (`#38BDF8`); remove `ThemeVibe.persianTurquoise`.<br>2) **Purple Rework:** Remove `Deep Lavender` (`ThemeVibe.electricLavender`); deepen `Deep Amethyst` (`ThemeVibe.deepAmethyst`) with pitch-black surfaces (`#05020A`) and bold royal jewel purple accents (`#B026FF`). |
| `lib/widgets/shamsi_agenda_banner.dart` | Shamsi Agenda | 1) **Centered Header Architecture:** Horizontally center top bar date display, and horizontally center action buttons (`+ Event`, `Pick Date`, `Calendar`) with responsive dynamic spacing matching the navigation bar below.<br>2) Dynamic calendar dot colors: Orange for holidays, pink for birthdays, blue for custom events. |
| `lib/widgets/task_card.dart` | Task Card UI | 1) **Postpone Action Button:** Rename button from `'Tomorrow'` to `'Postpone'`; show multiplier on button (`Postpone 2x`, `Postpone 3x`) when postponed ≥2x; completely remove the separate `'Postponed (1x)'` text box.<br>2) **Vertically Centered Reorder Handle:** Vertically center the drag handle on the left side across the card's full height.<br>3) Compact mini-tasks layout when description is empty.<br>4) 3-second hold opens edit modal.<br>5) Dynamic RTL text alignment for Persian titles/notes. |
| `lib/widgets/media_card.dart` | Media Card UI | 1) Desaturate "Enter Notes" placeholder text color to muted tone (45% opacity).<br>2) Integrate persistent disk image cache renderer (`SafeCoverImage` / `CachedNetworkImage`).<br>3) Add 3-second hold gesture to open centralized media edit modal. |
| `lib/widgets/safe_cover_image.dart` | Image Renderer | Enforce 3:4 aspect ratio with `BoxFit.cover` and local disk caching fallback. |
| `lib/main.dart` | Core Application | 1) **Task Sinking:** Completed (`Done`) tasks automatically move to the bottom of the list.<br>2) **Collapsible Task Streams:** Minimize Today's Focus and Backlog via arrow-only icon buttons (no text labels).<br>3) **Status Counters & Themed Progress Bar:** Section headers display Done/Cancel/Total breakdown with a linear progress bar colored dynamically by active theme.<br>4) **Compact Label Sub-Menu:** Replace single-column checkbox list with compact button chips in a responsive `Wrap`; remove `(Custom)` taglines; enable long-press to permanently remove any label from database.<br>5) **Recently Added Sorting:** Rename `'Custom Order'` to `'Recently Added'`, sorting by `createdAt` descending.<br>6) Drag auto-scroll near screen boundaries. |

---

## 3. Active Design Specifications (Version 2.4.0 Backlog)

### 3.1 Theme & Aesthetics

#### 3.1.1 Merge Persian Turquoise into Nordic Slate & Eliminate Persian Turquoise
- **Directive:** Merge the background colors of Persian Turquoise into Nordic Slate and remove Persian Turquoise from the theme catalog.
- **Specification for `minimalNordic` (Nordic Slate):**
  - `bgCanvas`: `Color(0xFF091319)` (Deep Teal Abyss)
  - `bgSurface`: `Color(0xFF0F1F28)` (Nocturnal Slate Surface)
  - `bgElevated`: `Color(0xFF162D3A)` (Elevated Teal Charcoal)
  - `accentPrimary`: `Color(0xFF38BDF8)` (Vibrant Ice Sky)
  - `textMain`: `Color(0xFFF0F9FF)` (Crisp Glacial White)
  - `textMuted`: `Color(0xFF7DD3FC)` (Soft Polar Cyan)
  - `textDim`: `Color(0xFF0284C7)` (Deep Arctic Blue)
  - `accentGradient`: `LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)])`
- **Removal:** Delete `ThemeVibe.persianTurquoise` from `enum ThemeVibe`, palette maps, and drawer settings.

#### 3.1.2 Purple Theme Consolidation: Remove Deep Lavender & Deepen Deep Amethyst
- **Removal:** Delete `Deep Lavender` (`ThemeVibe.electricLavender`) completely.
- **Deepening `Deep Amethyst` (`ThemeVibe.deepAmethyst`):**
  - Surfaces driven to abyssal, pitch-black plum tones for maximum contrast:
    - `bgCanvas`: `Color(0xFF05020A)` (Pure Abyssal Black Plum)
    - `bgSurface`: `Color(0xFF0F0419)` (Nocturnal Obsidian Violet)
    - `bgElevated`: `Color(0xFF1B072D)` (Midnight Amethyst Velvet)
  - Typography: `textMain: Color(0xFFFAF5FF)`, `textMuted: Color(0xFFE9D5FF)`, `textDim: Color(0xFFA855F7)`.
  - Accents: `accentPrimary: Color(0xFFB026FF)` (Bold High-Voltage Royal Jewel Purple), `accentGradient: LinearGradient(colors: [Color(0xFF7E22CE), Color(0xFFB026FF), Color(0xFFD946EF)])`.
- **The 3 Purple Theme Lineup:**
  1. **Deep Amethyst (`deepAmethyst`):** Canvas `#05020A` \| Surface `#0F0419` \| Accent `#B026FF`
  2. **Purple & Gold (`imperialGold`):** Canvas `#08040C` \| Surface `#140A1E` \| Accent `#F59E0B`
  3. **Purple & Orange (`purpleOrange`):** Canvas `#12061A` \| Surface `#1F0A2C` \| Accent `#FF6B00`

---

### 3.2 Daily Pulse & Shamsi Agenda

#### 3.2.1 Centered Top Bar Date & Centered Action Buttons with Dynamic Spacing
- **Centered Date Header:** Day number, month/year title, weekday, and Gregorian counterpart are wrapped in a horizontally centered column (`Alignment.center` / `MainAxisAlignment.center`).
- **Centered Action Buttons Row:** `+ Event`, `🗓️ Pick Date`, and `📅 Calendar` buttons reside in a centered row beneath the date.
- **Dynamic Proportional Spacing:** Wrapped in `LayoutBuilder` with `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.center)` and `Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly)` matching the quick navigation bar below. On 360dp mobile viewports, buttons scale down gracefully without line-wrapping or clipping.

#### 3.2.2 "Postpone" Action Button & Multiplier Counter
- **Button Renaming:** Change button text from `"Tomorrow"` to **`"Postpone"`**.
- **Dynamic Multiplier on Button:**
  - 0 postponements: `'Postpone'`
  - 1 postponement: `'Postpone'` (amber highlight indicator)
  - ≥2 postponements: Label directly displays multiplier: `'Postpone 2x'`, `'Postpone 3x'`, `'Postpone 4x'`.
- **Removal of Separate Text Box:** Completely delete the standalone `Text('Postponed (${task.postponedCount}x)')` box from `TaskCard`.
- **Gesture Architecture:**
  - Quick tap: Reschedules task to `currentDate + 1 day`, increments `postponedCount`, sets `status = TaskStatus.postponed`.
  - Long press (Hold): Opens clean Shamsi date picker sub-menu modal without any text prompts.

#### 3.2.3 Vertically Centered Left Reorder Handle & Compact Mini-Tasks
- **Vertically Centered Reorder Handle:**
  - Reorder drag handle (`Icons.drag_indicator`) is positioned strictly on the **left side** and vertically centered across the card's full height using `Row(crossAxisAlignment: CrossAxisAlignment.center)`.
  - Maintains proper vertical alignment regardless of card height (single-line mini-task vs. multi-line task with notes and badges).
- **Compact Mini-Tasks:**
  - When `task.notes.trim().isEmpty`: Card padding reduces to 8dp, bottom notes container is removed, and divider spacing collapses to 4dp.

#### 3.2.4 Completed ("Done") Tasks Sinking
- **Down-Listing Rule:** In both `_dailyTasks` and `_backlogTasks`, tasks are partitioned by status:
  ```dart
  int compareTaskExecutionState(Task a, Task b) {
    final aDone = a.status == TaskStatus.completed;
    final bDone = b.status == TaskStatus.completed;
    if (aDone != bDone) return aDone ? 1 : -1; // Done tasks sink to the bottom
    return a.orderIndex.compareTo(b.orderIndex);
  }
  ```
- **Reactivity:** Tapping `[Done]` automatically sinks the task to the bottom of the list. Unchecking it returns it to the active top section. Drag reordering operates within active or completed groups.

#### 3.2.5 Collapsible Task Lists (Today's Focus & Backlog) with Arrow-Only Controls
- **State Flags:** `bool _isDailyFocusCollapsed = false;` and `bool _isBacklogCollapsed = false;`.
- **Arrow-Only Toggle Button:** Toggled via an `IconButton` or `InkWell` with `Icon(_isDailyFocusCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 20, color: palette.accentPrimary)`. **Strictly no text labels** (no "Collapse" or "Expand").
- **Behavior:** Collapsing hides the list body via `AnimatedCrossFade`. The section header remains visible with title, arrow toggle, status breakdown counts, and the themed progress bar.

#### 3.2.6 Task Status Breakdown Counters & Dynamic Theme-Colored Progress Bar
- **Header Counters:** Computes metrics and displays `$doneCount/$total Done` pill badge alongside a muted canceled badge (`• $canceledCount canceled` when `canceledCount > 0`).
- **Dynamic Themed Progress Bar:** A horizontal linear progress bar (height: 5dp, radius: 4dp) rendered below the header title. Fill width is calculated as `(doneCount / total).clamp(0.0, 1.0)`. The bar shader gradient and shadow dynamically bind to the current theme vibe (`palette.accentGradient` / `palette.accentGlow`).

#### 3.2.7 Custom Events Restoration & Dynamic Multi-Color Dots
- **Add Custom Event (`+ Event`):** Opens modal to create birthdays (`🎂 Birthday` - Pink badge) and milestones (`🎯 Custom Event` - Blue badge). Persisted in `StorageService`.
- **Calendar Dot Priorities:** In month grid, dots dynamically color-code:
  1. Priority 1 (Pink `#EC4899`): Dates containing birthdays.
  2. Priority 2 (Blue `#60A5FA`): Dates containing custom user events.
  3. Priority 3 (Orange `#F59E0B`): Dates with official Iranian Solar Hijri holidays.

#### 3.2.8 Typography, Persian RTL, and Interaction Standards
- **Font Simplification:** Completely remove `Vazirmatn` font family (`assets/fonts/Vazirmatn-*.ttf` and `pubspec.yaml`). Perso-Arabic text natively falls back to Android system fonts (`Noto Sans Arabic` / `Roboto`).
- **Sentence Case Input:** Enforce sentence capitalization (`SentenceCaseTextInputFormatter`) across all input fields.
- **Persian RTL Auto-Detection:** `RtlDetectionService` detects Perso-Arabic unicode ranges to set `textDirection: TextDirection.rtl` and `textAlign: TextAlign.right` for cards and input fields.
- **Card Edit Workflow:** 3-second hold on any task card opens unified edit dialog. Adding notes dynamically transitions mini-tasks to standard tasks.
- **Drag Auto-Scroll:** Dragging a task within 90dp of top/bottom viewport edges smoothly auto-scrolls the list.

---

### 3.3 Entertainment Ledger

#### 3.3.1 Chronological Media Sorting: Renaming "Custom Order" to "Recently Added"
- **Label Update:** Rename dropdown menu item from `'Custom Order'` to **`'Recently Added'`**.
- **Implementation:** When `_mediaSort == 'custom'`, items are sorted chronologically by `createdAt` descending:
  ```dart
  list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  ```
  Newly added media items appear prominently at the top of the collection.

#### 3.3.2 Multi-Platform Video Game Cover Architecture: Nintendo & Console Exclusives
- **Current Limitation:** Existing search queries Steam Store API and CheapShark fallback, which exclusively track PC digital releases. Console exclusives (Nintendo Switch, PS5, Xbox, retro) return 0 results.
- **Multi-Source Fetch Pipeline (`CoverFetchService`):**
  1. **Steam Store API:** Primary source for PC titles (vertical 600x900 library posters).
  2. **RAWG Video Games Database API (`api.rawg.io`):** Over 500,000 games across 50+ platforms including all Nintendo consoles (Switch, Wii U, GameCube, N64, SNES, NES, Game Boy, DS, 3DS), PlayStation (PS1–PS5), and Xbox.
  3. **LaunchBox Games Database Open Archive:** Comprehensive physical box art archive for console and retro games.
  4. **Libretro Boxart CDN (`github.com/libretro-thumbnails`):** Direct zero-auth box art CDN for Nintendo and retro consoles.
  5. **Aspect Ratio Standardization:** `SafeCoverImage` encloses all artwork in a uniform 3:4 aspect ratio with `BoxFit.cover` so console box art crops cleanly without distortion.

#### 3.3.3 Modernized Label Sub-Menu: Compact Button Wrap & Database Deletion
- **Default Presets Overhaul:** Remove `'Masterpiece'` from default presets; add `'Fantasy'`. Standard list: `['Sci-Fi', 'Drama', 'Horror', 'Fantasy', 'RPG', 'Ongoing']`.
- **Space-Filling Compact Button Wrap:** Sub-menu dialog replaces the single-column vertical `CheckboxListTile` list with a responsive, dense **`Wrap` of small toggleable button chips** (`spacing: 8, runSpacing: 8`). Fully utilizes horizontal and vertical space, eliminating excessive scrolling. Selected chips highlight with `palette.accentPrimary` and black text.
- **Long-Press Deletion from Database:** Long-pressing any label button in the sub-menu triggers a confirmation dialog to permanently delete the label from the global database. Deletes from active label pool and untags affected media items.
- **Universal Tag Treatment:** Remove the `(Custom)` tagline completely; all tags render cleanly by name. Both custom tags and default presets (e.g. "Fantasy", "Horror") can be deleted.
- **Persistence:** Active label pool is persisted in `StorageService` (`_activeLabelsKey` in `SharedPreferences`).

#### 3.3.4 Media Persistence, Styling, and Edit Interactions
- **Persistent Disk Image Cache:** Integrate `cached_network_image: ^3.4.1` into `SafeCoverImage` with CORS fallback. Zero network calls on subsequent app launches.
- **Desaturated Notes Placeholder:** Placeholder hint text styled with `palette.textDim.withValues(alpha: 0.45)`.
- **3-Second Media Tile Hold:** Long-pressing any media card (List or Grid view) for 3 seconds opens the centralized media edit dialog (`_showEditMediaDialog`).

---

## 4. Verification & Testing Checklist

- [x] **Font Elimination:** App builds cleanly without `Vazirmatn`; Persian text falls back smoothly to Android system `Noto Sans Arabic`.
- [x] **Sentence Case:** All input dialogs capitalize only the first letter of each sentence.
- [x] **Custom Events & Dots:** `+ Event` creates birthdays (pink dot) and custom events (blue dot); Iranian holidays render orange dots.
- [x] **Centered Top Bar:** Top date is horizontally centered; `+ Event`, `Pick Date`, and `Calendar` buttons are centered with responsive dynamic spacing.
- [x] **Postpone Button:** Button reads "Postpone"; shows multiplier `Postpone 2x`, `Postpone 3x` when postponed ≥2x; separate "Postponed (1x)" text box is completely gone.
- [x] **Vertically Centered Drag Handle:** Task drag handle is vertically centered on the left side across the card's full height.
- [x] **Compact Mini-Tasks:** Description-less tasks render with tight padding and collapsed dividers.
- [x] **Done Tasks Sinking:** Completed tasks automatically move to the bottom of Today's Focus and Backlog.
- [x] **Collapsible Task Lists:** Today's Focus and Backlog minimize via arrow-only icon toggles (no text labels).
- [x] **Status Counters & Themed Progress Bar:** Section headers display Done/Cancel/Total counts with a theme-colored progress bar.
- [x] **Theme Consolidation:** Nordic Slate adopts Persian Turquoise background (`#091319`); Persian Turquoise is removed from the theme list.
- [x] **Deep Amethyst Rework:** Deep Lavender is removed; Deep Amethyst has pitch-black surfaces (`#05020A`) and bold royal jewel purple accents (`#B026FF`).
- [x] **Persian RTL Support:** Persian task titles align RTL; inputs dynamically flip to RTL when typing Persian.
- [x] **Recently Added Sort:** Entertainment sorting dropdown displays "Recently Added" and sorts items chronologically.
- [x] **Console Game Cover Architecture:** Fallback pipeline handles Nintendo Switch and console exclusives (RAWG / LaunchBox / Libretro).
- [x] **Label Defaults & Compact Sub-Menu:** "Masterpiece" removed, "Fantasy" added; label sub-menu renders as compact button chips in a `Wrap`; `(Custom)` tags removed; long-press deletes any label from database.
- [x] **Cover Disk Cache & 3-Second Hold:** Cached posters load offline with 0ms latency; 3-second hold on task cards and media cards opens edit dialogs.

---

## 5. Architectural Changelog (Completed Versions)

| Version | Key Enhancements & Milestones Completed |
| :--- | :--- |
| **v1.0.0 – v2.0.0** | Core Day-Planner & Shamsi Agenda; Split task streams; Entertainment ledger (Books, TV, Movies, Games); Local storage persistence; Theme system; Media deletion with cascade handling. |
| **v2.1.0** | Shamsi calendar integration (`persian_datetime_picker`, `persian_number_utility`); Multi-platform app icon generation (Android mipmaps, Web icons, Windows ico); Auto-fetch cover CORS proxies & User-Agent headers; Horizontal swipe page transitions. |
| **v2.2.0** | 4:3 poster aspect ratio enforcement; Progress update numerical validation (`cur <= tot`); Backlog "Assign to Day" context binding; Centered month navigation controls (`« Month`, `Month »`); Comprehensive holiday catalog. |
| **v2.3.0** | Vazirmatn font removal blueprint; Sentence case formatting engine; Persian RTL detection service; Cover art persistent disk cache architecture; Mini-task layout specifications. |
| **v2.4.0** | Theme harmonization (Persian/Nordic merge, Deep Amethyst pitch-black overhaul); Postpone button evolution & multiplier badge; Top bar date & button centering; Sinking Done tasks; Collapsible task streams; Themed progress bars; Space-filling label button wrap; Long-press label deletion; "Fantasy" preset; "Recently Added" sorting; Console/Nintendo game cover pipeline. |
