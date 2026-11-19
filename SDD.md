# Software Design Document (SDD)
## Project: NSH Pulse (Lightweight Personal Assistant & Daily Pulse)

**Document Version:** 2.5.0  
**Target Platforms:** Android (API 26+, optimized for Samsung Galaxy A12 & modern devices), Flutter Web (Chrome), Windows Desktop  
**Repository:** Local git repository initialized (`main`)  
**Status:** Approved Architecture & Specification (Version 2.5.0 Released)

---

## 1. System Overview & Core Pillars

**NSH Pulse** is a zero-latency, local-first companion unifying daily agenda planning, task execution streams, and entertainment tracking.

### Core Functional Pillars
1. **Contextual Day-Planner & Shamsi Agenda:** Solar Hijri calendar integration, official Iranian holidays, custom user events (birthdays/milestones), dynamic dot indicators, incomplete-day visual indicators in calendar grid, and bilingual Gregorian/Jalali sync.
2. **Dual-Stream Task Engine ("Daily Pulse"):** Split streams ("Today's Focus" vs. "Orbit & Backlog"), 3-state execution (`Done`, `Postpone`, `Cancel`), automatic sinking of completed tasks, collapsible stream sections, dynamic Persian RTL detection, compact mini-tasks, and touch/drag reordering with boundary auto-scroll.
3. **Universal Entertainment Ledger:** Books, TV Shows, Movies, and Video Games with metric progress tracking, half-point ratings (1.0–10.0), persistent offline cover art disk caching, multi-platform cover fetching (Steam + Console/Nintendo APIs), compact label selector sub-menu, chronological sorting with persistent sort preference, description field on creation, fetch-info button for auto-populating release data (episodes/runtime), and smart date tracking (created/completed/re-opened).
4. **Adaptive Aesthetics & Dynamic Typography:** High-contrast Dark Vibe palettes with dynamic theme-colored progress indicators, custom-curated fonts (`Comic Neue`, `Quicksand`, `Fira Code`, `Lora`, and clean system sans), configurable global font size scaling, and zero external font asset bloat.

---

## 2. Technical Architecture & File Modification Matrix

| File Path | Component | Current Role & Version 2.5.0 Specification |
| :--- | :--- | :--- |
| `pubspec.yaml` | Manifest | Remove `Vazirmatn` font family; declare `cached_network_image: ^3.4.1` for poster disk caching. |
| `assets/fonts/` | Asset Directory | Remove unused `Vazirmatn-Regular.ttf` and `Vazirmatn-Bold.ttf` binaries. |
| `lib/models/media_item.dart` | Data Model | Add `displayDate` lifecycle timestamp tracking (created, finished, re-opened); add serialization and copyWith support. |
| `lib/services/media_info_fetch_service.dart` | Metadata Fetching | Query external APIs for media release year, TV show episode count, and movie runtime in minutes. |
| `lib/services/sentence_case_service.dart` | Text Formatting | Enforce sentence-level capitalization (`SentenceCaseTextInputFormatter`) across all inputs. |
| `lib/services/rtl_detection_service.dart` | Typography / Bidi | Auto-detect Perso-Arabic unicode ranges to dynamically flip `TextDirection` (RTL/LTR) for tasks and text inputs. |
| `lib/services/cover_cache_service.dart` | Media Caching | Manage local persistent disk caching for fetched media covers so images are never re-downloaded. |
| `lib/services/cover_fetch_service.dart` | Cover Fetching | Multi-source cover fetching: Steam API for PC games + fallback to RAWG / LaunchBox / Libretro CDNs for Nintendo & console games. |
| `lib/services/media_label_service.dart` | Labels & Tags | 1) Replace default preset `'Masterpiece'` with `'Fantasy'`.<br>2) Provide database deletion methods to permanently remove default and custom labels. |
| `lib/services/storage_service.dart` | Persistence | Persist active label list, custom events, media sort preference, and font size scale in `SharedPreferences` across app restarts. Merge default events only when not previously deleted by user (`_deletedEventIds` exclusion set). |
| `lib/theme/app_theme.dart` | Palettes & Themes | 1) **Persian/Nordic Consolidation:** Merge Persian Turquoise dark teal background (`#091319`, `#0F1F28`, `#162D3A`) into `Nordic Slate` with icy sky foreground (`#38BDF8`); remove `ThemeVibe.persianTurquoise`.<br>2) **Purple Rework:** Remove `Deep Lavender` (`ThemeVibe.electricLavender`); deepen `Deep Amethyst` (`ThemeVibe.deepAmethyst`) with pitch-black surfaces (`#05020A`) and bold royal jewel purple accents (`#B026FF`). |
| `lib/widgets/settings_drawer.dart` | Settings UI | Add "Font Size" scaling slider (80%–140%) with live preview and descriptive size labels (Compact, Default, Large, Extra Large). |
| `lib/widgets/shamsi_agenda_banner.dart` | Shamsi Agenda | 1) **Centered Header Architecture:** Horizontally center top bar date display, and horizontally center action buttons (`+ Event`, `Pick Date`, `Calendar`) with responsive dynamic spacing matching the navigation bar below.<br>2) Dynamic calendar dot colors: Orange for holidays, pink for birthdays, blue for custom events.<br>3) **Reversed Shamsi Date Order:** Display top-bar date as `Day MonthName Year` (e.g., `۲۱ آبان ۱۴۰۵`) instead of `Day Year MonthName`.<br>4) **Incomplete Day Visual Indicator:** Calendar grid days where tasks exist but are not all 100% done render a subtle accent-colored bottom-border underline. |
| `lib/widgets/task_card.dart` | Task Card UI | 1) **Postpone Action Button:** Rename button from `'Tomorrow'` to `'Postpone'`; show multiplier on button (`Postpone 2x`, `Postpone 3x`) when postponed ≥2x; completely remove the separate `'Postponed (1x)'` text box.<br>2) **Vertically Centered Reorder Handle:** Vertically center the drag handle on the left side across the card's full height.<br>3) Compact mini-tasks layout when description is empty.<br>4) 3-second hold opens edit modal.<br>5) Dynamic RTL text alignment for Persian titles/notes.<br>6) **Remove Media Units Label Next to "To Backlog":** Hide the `'+N on ch..'` label displayed beside the "To Backlog" button for media-linked daily tasks. The media goal badge at the top of the card is sufficient. |
| `lib/widgets/media_card.dart` | Media Card UI | 1) Desaturate "Enter Notes" placeholder text color to muted tone (45% opacity).<br>2) Integrate persistent disk image cache renderer (`SafeCoverImage` / `CachedNetworkImage`).<br>3) Add 3-second hold gesture to open centralized media edit modal.<br>4) **100% Completed Visual Identity:** Render 1.5dp emerald green border (`0x8010B981`), background emerald tint, cover "Done" overlay badge, emerald progress gradient, and replace "Schedule" action button with non-interactive "Completed" badge.<br>5) **Hide Hold Button on Completed Media:** When `item.isCompleted`, hide the Hold checkbox and label entirely from both list and grid cards.<br>6) **Remove Description Quotation Marks:** Display `personalNotes` without wrapping `"..."` quotes in the description area.<br>7) **Display Created/Completed Date:** Show a Gregorian date label (e.g., `Nov 17, 2026`) on each media tile, sourced from `MediaItem.displayDate`. |
| `lib/widgets/safe_cover_image.dart` | Image Renderer | Enforce 3:4 aspect ratio with `BoxFit.cover` and local disk caching fallback. |
| `lib/main.dart` | Core Application | 1) **Task & Media Sinking:** Completed (`Done`) tasks and 100% completed media items automatically move to the bottom of all lists.<br>2) **Collapsible Task Streams:** Minimize Today's Focus and Backlog via arrow-only icon buttons (no text labels).<br>3) **Status Counters & Themed Progress Bar:** Section headers display Done/Cancel/Total breakdown with a linear progress bar colored dynamically by active theme.<br>4) **Compact Label Sub-Menu:** Replace single-column checkbox list with compact button chips in a responsive `Wrap`; remove `(Custom)` taglines; enable long-press to permanently remove any label from database.<br>5) **Recently Added Sorting:** Rename `'Custom Order'` to `'Recently Added'`, sorting by `createdAt` descending.<br>6) Drag auto-scroll near screen boundaries.<br>7) **Media Scheduling Lock:** Block scheduling for completed media items.<br>8) **Persistent Media Sort Preference:** Persist `_mediaSort` selection in `StorageService` across app restarts.<br>9) **Description on Add Media:** Include a personal notes/description text field in the Add Media dialog.<br>10) **Fetch Info Button:** Add a "Fetch Info" button in Add/Edit Media dialogs to auto-populate release year, plus episodes count for TV shows and runtime for movies from external APIs.<br>11) **Smart Media Date Tracking:** Set `displayDate` to `createdAt` on first add; update to completion date when progress reaches 100%; re-open (drop below 100%) updates to current date. |

---

## 3. Active Design Specifications (Version 2.5.0 Backlog)

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

#### 3.3.5 Completed ("Done") Media Sinking, Scheduling Lock & Emerald Visual Styling
- **Down-Listing Rule:** In `_filteredMediaItems`, media items reaching 100% completion (`item.isCompleted == true`) automatically sink to the bottom across all category filters (`all`, `book`, `tvShow`, `movie`, `videoGame`) and sort options (`custom` / Recently Added, `score`, `progress`, `year`, `name`). Relative sort order is preserved within both active and completed partitions:
  ```dart
  final active = list.where((m) => !m.isCompleted).toList();
  final done = list.where((m) => m.isCompleted).toList();
  return [...active, ...done];
  ```
- **Media Scheduling Lock:** Completed media items cannot be scheduled for daily goals:
  - `MediaCard` UI: Replaces the interactive "Schedule Today" (list) or "Schedule" (grid) action button with a non-interactive green "Completed" pill badge (`Color(0xFF10B981)`).
  - Central Handler Guard: `_scheduleMediaToday(MediaItem item)` blocks execution with a user notification snackbar if invoked on an already completed item.
  - Validation Service: `MediaGoalSyncService.canSchedule(item)` returns `false` and `validateGoalAmount` rejects completed items with an explicit error message.
- **Visual Distinction & Emerald Green Border:**
  - **Color Rationale:** Emerald green (`Color(0x8010B981)`) was chosen over theme accent colors because theme colors represent interactive focus and active states, whereas green is the universal indicator for completion across Pulse Assistant (matching `TaskStatus.done` green borders in `TaskCard`). Green also avoids collision with amber on-hold borders (`0x66F59E0B`).
  - **Card Container:** Styled with a 1.5dp emerald green border (`0x8010B981`) and a subtle emerald-tinted elevated background (`Color.alphaBlend(Color(0x0F10B981), palette.bgElevated)`).
  - **Poster & Progress Accents:** Cover box displays a top-left green "Done" overlay badge (`Color(0xD9059669)`), percentage text renders in emerald green, and the progress bar renders an emerald completion gradient (`[Color(0xFF10B981), Color(0xFF34D399)]`).

---

### 3.4 Version 2.5.0 — New Features & Fixes

#### 3.4.1 Hide Hold Button on Completed Media Items
- **Problem:** When a media item reaches 100% completion, the "Hold" checkbox and label still appear on the card and can be tapped, but toggling hold on a completed item is functionally meaningless and confusing.
- **Fix — List Card:** Inside `_buildListCard`, wrap the Hold `InkWell` + `Checkbox` row in a conditional: only render when `!item.isCompleted`. When completed, the entire Hold section is removed from the action buttons row; the existing "Completed" emerald badge already occupies the left side.
- **Fix — Grid Card:** Inside `_buildGridCard`, wrap the "⏸ On-hold / ▶ Active" toggle text in the same `!item.isCompleted` guard. When completed, replace the row with a minimal non-interactive "✓ Done" label or omit it entirely since the emerald "Completed" badge is already above.
- **Files:** `lib/widgets/media_card.dart`

#### 3.4.2 Reverse Shamsi Month/Year Order in Top Bar
- **Problem:** The top-bar date currently displays as `۲۱ ۱۴۰۴ آبان` (Day Year MonthName). The correct Persian reading order should be `۲۱ آبان ۱۴۰۵` (Day MonthName Year).
- **Fix:** In `shamsi_agenda_banner.dart` line 215, change the string interpolation from:
  ```dart
  '$monthName ${_toPersianDigits(_selectedDate.year)}'
  ```
  to a properly spaced month-first format:
  ```dart
  '$monthName  ${_toPersianDigits(_selectedDate.year)}'
  ```
  Since this text is rendered RTL inside a row that starts with the large day number, the visual result becomes: `۲۱` (large) → then `آبان  ۱۴۰۵` (month name, non-breaking space, year) on the right side column.
- **Non-Breaking Space:** Use a Unicode non-breaking space (`\u00A0`) or double regular space between month name and year to ensure they never collapse visually: `'$monthName\u00A0${_toPersianDigits(_selectedDate.year)}'`.
- **Files:** `lib/widgets/shamsi_agenda_banner.dart`

#### 3.4.3 Remove Quotation Marks from Media Descriptions
- **Problem:** In `media_card.dart`, the personal notes/description text is rendered with wrapping quotes: `'📝 "${item.personalNotes}"'`. This looks cluttered on compact tiles.
- **Fix:** In `_buildListCard` description container, change:
  ```dart
  '📝 "${item.personalNotes}"'
  ```
  to:
  ```dart
  '📝 ${item.personalNotes}'
  ```
- **Files:** `lib/widgets/media_card.dart`

#### 3.4.4 Add Description Field When Adding a Media Tile
- **Problem:** The current `_showAddMediaDialog` does not include a personal notes/description field. Users must add a media item first, then separately edit notes — an extra step.
- **Fix:** Add a `notesController` `RtlAwareTextField` in the Add Media dialog content, positioned between the Labels picker and the Cover Art section:
  ```dart
  final notesController = TextEditingController();
  // ...inside dialog content Column:
  const SizedBox(height: 10),
  RtlAwareTextField(
    controller: notesController,
    maxLines: 3,
    style: TextStyle(color: _palette.textMain),
    decoration: InputDecoration(
      labelText: 'Personal Description / Notes',
      hintText: '+ Add personal description/notes (optional)...',
      hintStyle: TextStyle(color: _palette.textDim.withValues(alpha: 0.45)),
      labelStyle: TextStyle(color: _palette.textMuted),
      filled: true,
      fillColor: _palette.bgSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  ```
- **On Save:** Pass `personalNotes: notesController.text.trim().isEmpty ? null : toSentenceCase(notesController.text.trim())` to the `MediaItem` constructor.
- **Files:** `lib/main.dart` (`_showAddMediaDialog`)

#### 3.4.5 Fetch Information Button (Release Data, Episodes, Runtime)
- **Problem:** When adding or editing a media item, the user must manually enter the release year, total episodes (TV shows), or runtime (movies). This data is readily available from public APIs.
- **Feature — "Fetch Info" Button:** Add a `🔎 Fetch Info` button in both the Add Media and Edit Media dialogs, positioned adjacent to or below the Release Year field.
- **Behavior on Tap:**
  1. Requires a non-empty title in the title field; shows inline error `'Enter title first!'` otherwise.
  2. Queries the appropriate external API based on `selectedType`:
     - **TV Shows:** Fetch total episode count across all seasons (e.g., from TMDb or OMDb) and auto-populate `totalController`.
     - **Movies:** Fetch runtime in minutes and auto-populate `totalController` with that value.
     - **Books / Video Games:** Fetch release year only (total pages/missions are too variable for auto-fill).
  3. Auto-fills `yearController` with the fetched release year for all media types.
  4. Shows a brief inline confirmation message: `'Fetched: 2024, 39 episodes'` or `'Fetched: 2024, 166 min'`.
- **API Sources:** Reuse existing `CoverFetchService` pipeline or extend with dedicated metadata endpoints (TMDb `/search/tv`, `/search/movie`, OMDb `?t=`).
- **New Service:** `lib/services/media_info_fetch_service.dart`
  ```dart
  class MediaInfoFetchService {
    /// Returns a MediaInfoResult containing releaseYear, episodeCount (TV),
    /// runtimeMinutes (Movie), or null if not found.
    static Future<MediaInfoResult?> fetchInfo({
      required String title,
      required MediaType type,
    }) async { ... }
  }

  class MediaInfoResult {
    final int? releaseYear;
    final int? episodeCount;    // TV Shows only
    final int? runtimeMinutes;  // Movies only
  }
  ```
- **Files:** `lib/services/media_info_fetch_service.dart` (new), `lib/main.dart` (`_showAddMediaDialog`, `_showEditMediaDialog`)

#### 3.4.6 Fix Persistent Default Custom Events After Deletion (Birthday & Exam Bug)
- **Problem:** Every time the app opens, `loadShamsiEvents()` in `StorageService` merges saved events with `ShamsiEvent.defaultEvents`. If the user deletes a default event (e.g., `b_maryam` "تولد مریم" or `c_exam` "Final Exam Submission"), it re-appears on next launch because the merge loop re-adds any default whose `id` is missing from saved data.
- **Root Cause:** Lines 114–121 in `storage_service.dart`:
  ```dart
  final existingIds = {for (final e in saved) e.id};
  final merged = List<ShamsiEvent>.from(saved);
  for (final def in ShamsiEvent.defaultEvents) {
    if (!existingIds.contains(def.id)) {
      merged.add(def);  // ← Re-adds deleted defaults every time
    }
  }
  ```
- **Fix — Deleted Event ID Exclusion Set:**
  1. Add a new `SharedPreferences` key: `static const String _keyDeletedEventIds = 'nsh_deleted_event_ids_v1';`.
  2. When the user deletes a custom or default event via `_removeShamsiEvent(event)`, persist the event's `id` into `_deletedEventIds`:
     ```dart
     void _removeShamsiEvent(ShamsiEvent event) {
       setState(() {
         _events.removeWhere((e) => e.id == event.id);
       });
       widget.storage.saveShamsiEvents(_events);
       widget.storage.addDeletedEventId(event.id); // NEW
     }
     ```
  3. In `loadShamsiEvents()`, filter the merge to exclude deleted IDs:
     ```dart
     final deletedIds = loadDeletedEventIds(); // Returns Set<String>
     for (final def in ShamsiEvent.defaultEvents) {
       if (!existingIds.contains(def.id) && !deletedIds.contains(def.id)) {
         merged.add(def);
       }
     }
     ```
  4. `StorageService` new methods:
     ```dart
     Set<String> loadDeletedEventIds() {
       return (_prefs.getStringList(_keyDeletedEventIds) ?? []).toSet();
     }
     Future<void> addDeletedEventId(String id) async {
       final ids = loadDeletedEventIds()..add(id);
       await _prefs.setStringList(_keyDeletedEventIds, ids.toList());
     }
     ```
- **Files:** `lib/services/storage_service.dart`, `lib/main.dart`

#### 3.4.7 Persist Media Sort Preference Across App Restarts
- **Problem:** The media sorting dropdown (`_mediaSort`) defaults to `'custom'` (Recently Added) every time the app launches. The user's last selected sort (e.g., Highest Score, Name A-Z) is lost.
- **Fix:**
  1. Add a new `SharedPreferences` key in `StorageService`: `static const String _keyMediaSort = 'nsh_media_sort_v1';`.
  2. Add `loadMediaSort()` and `saveMediaSort(String sort)` methods.
  3. In `_HomeScreenState.initState()`, load: `_mediaSort = widget.storage.loadMediaSort();`
  4. In the `DropdownButton.onChanged` handler, persist: `widget.storage.saveMediaSort(val);`
- **Files:** `lib/services/storage_service.dart`, `lib/main.dart`

#### 3.4.8 Remove "+N on check" Label Next to "To Backlog" Button
- **Problem:** For media-linked daily tasks, the bottom action row displays both a "To Backlog" button and a `'+3 on check'` text label beside it. This label is redundant because the top of the task card already shows a `'🎯 Media Goal: Title • +3'` badge. It also gets clipped on narrow screens.
- **Fix:** In `task_card.dart`, remove the conditional block that renders the `'+N on check'` text next to the "To Backlog" button:
  ```dart
  // REMOVE this block entirely:
  if (task.linkedMediaId != null) ...[
    const SizedBox(width: 8),
    Text(
      '+${task.mediaUnitsToAdvance?.toInt() ?? 0} on check',
      ...
    ),
  ],
  ```
  Also remove the standalone `'+N on check'` text at the bottom of the action row (the `else if (task.linkedMediaId != null)` branch after the backlog button).
- **Files:** `lib/widgets/task_card.dart`

#### 3.4.9 Global Font Size Scaling in Appearance Settings
- **Feature:** Add a new "FONT SIZE" section in `SettingsDrawer` allowing the user to increase or decrease the global text size across the entire app.
- **Implementation:**
  1. **New State/Config:**
     - `double _fontSizeScale` in `_NSHAssistantAppState` (default `1.0`, range `0.8` to `1.4`, step `0.1`).
     - Stored in `StorageService` under key `nsh_font_size_scale_v1`.
  2. **Settings UI:** Below the Font Style grid in `SettingsDrawer`, add a "FONT SIZE" section with:
     - A `Slider` (min 0.8, max 1.4, 6 divisions) showing the current scale factor.
     - Preview label: `'Aa — ${(scale * 100).round()}%'`.
     - Descriptive labels: 80% = "Compact", 100% = "Default", 120% = "Large", 140% = "Extra Large".
  3. **Global Application:** In `NSHAssistantApp.build()`, apply the scale factor via `MediaQuery`:
     ```dart
     MaterialApp(
       builder: (context, child) {
         final mediaQueryData = MediaQuery.of(context);
         return MediaQuery(
           data: mediaQueryData.copyWith(
             textScaler: TextScaler.linear(_fontSizeScale),
           ),
           child: child!,
         );
       },
       ...
     );
     ```
  4. **Callbacks:** Add `onFontSizeScaleChanged(double)` callback from `SettingsDrawer` to `_NSHAssistantAppState`.
- **Files:** `lib/widgets/settings_drawer.dart`, `lib/main.dart`, `lib/services/storage_service.dart`

#### 3.4.10 Smart Created/Completed Date Tracking on Media Tiles
- **Problem:** Media tiles currently have a `createdAt` field (used for sorting) but do not display any date to the user. The user wants to see when they added or finished a media item.
- **Data Model Enhancement — `MediaItem`:**
  1. Add a new field: `DateTime displayDate` — this represents the "lifecycle date" shown on the tile.
  2. `displayDate` defaults to `createdAt` when first added.
  3. **Date Update Rules:**
     - When `progressCurrent` reaches `progressTotal` (100% completion): `displayDate` updates to `DateTime.now()` (the finishing date).
     - If the user later edits the media and progress drops below 100% (re-opened): `displayDate` updates to `DateTime.now()` (the re-opening date).
     - If the user updates the media while it stays below 100%: `displayDate` does NOT change (stays as the last lifecycle transition date).
  4. **Serialization:** Add `'displayDate'` to `toJson()` and `fromJson()`. For backward compatibility, `fromJson` falls back to `createdAt` when `'displayDate'` key is absent.
  5. **`copyWith`:** Add `displayDate` parameter.
- **Date Display on Card:**
  - **List Card:** Show the date as a small muted label (e.g., `Nov 17, 2026`) below the labels row or beside the year badge:
    ```dart
    Text(
      _formatDisplayDate(item.displayDate), // 'Nov 17, 2026'
      style: TextStyle(fontSize: 9, color: palette.textDim),
    ),
    ```
  - **Grid Card:** Show the date below the year text, same font size (9–10).
  - **Format:** Gregorian date, `MMM dd, yyyy` (e.g., `Nov 17, 2026`). No time component.
- **Date Update Logic in `_showEditMediaDialog` and `_showUpdateProgressDialog`:**
  ```dart
  final wasCompleted = item.isCompleted;
  // ... apply progress update ...
  final nowCompleted = updatedItem.isCompleted;
  DateTime newDisplayDate = item.displayDate;
  if (!wasCompleted && nowCompleted) {
    newDisplayDate = DateTime.now(); // Just finished
  } else if (wasCompleted && !nowCompleted) {
    newDisplayDate = DateTime.now(); // Re-opened
  }
  updatedItem = updatedItem.copyWith(displayDate: newDisplayDate);
  ```
- **Files:** `lib/models/media_item.dart`, `lib/widgets/media_card.dart`, `lib/main.dart`

#### 3.4.11 Visual Indicator for Incomplete Days in Shamsi Calendar Grid
- **Feature:** When the calendar grid is expanded, days that have scheduled tasks where not all tasks are marked "Done" should display a visual indicator, distinguishing them from days with no tasks or fully completed days.
- **Design — Accent Underline Bar:**
  - For each day cell in the month grid, query the task list for tasks assigned to that Jalali date.
  - If tasks exist and **not all** have `status == TaskStatus.done` (i.e., the day is "incomplete"), render a small **accent-colored horizontal bar** (2dp height, 60% of cell width) at the bottom of the cell, inside the existing `Stack`.
  - If all tasks for that day are done, render a small **emerald green bar** instead (subtle success indicator).
  - If no tasks exist for that day, no bar is rendered.
  - The bar coexists with the existing event dot (dot is centered at `bottom: 2`, bar is at `bottom: 0` with full width).
- **Data Flow:**
  - `ShamsiAgendaBanner` receives the task list (or a precomputed map of `{jalaliKey: (totalCount, doneCount)}`) as a new parameter.
  - In `_HomeScreenState._buildDailyPulseView`, compute the map from `_tasks` and pass it to `ShamsiAgendaBanner`.
- **Implementation:**
  ```dart
  // In ShamsiAgendaBanner:
  final Map<String, ({int total, int done})>? taskCompletionMap;

  // In GridView itemBuilder, after rendering the day number and dot:
  final dayKey = '${_selectedDate.year}-${_selectedDate.month}-$dayNum';
  final stats = widget.taskCompletionMap?[dayKey];
  if (stats != null && stats.total > 0)
    Positioned(
      bottom: 0,
      left: 4,
      right: 4,
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          color: stats.done >= stats.total
              ? const Color(0xFF10B981)   // All done: emerald
              : palette.accentPrimary.withValues(alpha: 0.6), // Incomplete: accent
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    ),
  ```
- **Files:** `lib/widgets/shamsi_agenda_banner.dart`, `lib/main.dart`

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
- [x] **Done Media Sinking:** Media items at 100% automatically sink to the bottom of every filtered and sorted list.
- [x] **Media Scheduling Lock:** Completed media items cannot be scheduled again for daily goals in UI, validation service, and scheduling handler.
- [x] **Media Emerald Green Border & Completed Badge:** 100% media cards render an emerald green border (`0x8010B981`), "Completed" action badge, and "Done" cover overlay.
- [x] **v2.5.0 — Hold Button Hidden on Completed Media:** Hold checkbox/toggle is completely absent from media cards at 100% completion.
- [x] **v2.5.0 — Reversed Shamsi Date Order:** Top bar displays Day MonthName Year (`۲۱ آبان ۱۴۰۵`), not Day Year MonthName.
- [x] **v2.5.0 — No Quotation Marks on Descriptions:** Media tile descriptions render without wrapping `"..."` quotes.
- [x] **v2.5.0 — Description on Add Media:** Add Media dialog includes a personal description/notes text field.
- [x] **v2.5.0 — Fetch Info Button:** Add/Edit Media dialogs include a "Fetch Info" button that auto-populates release year, episode count (TV), and runtime (movies).
- [x] **v2.5.0 — Default Event Deletion Fix:** Deleted default events (birthdays, custom dates) no longer re-appear after app restart.
- [x] **v2.5.0 — Persistent Media Sort:** Sort preference persists across app restarts via `SharedPreferences`.
- [x] **v2.5.0 — Remove "+N on check" Label:** Redundant `'+N on check'` text removed from bottom action row of media-linked tasks; top badge is sufficient.
- [x] **v2.5.0 — Font Size Scaling:** Appearance settings include a Font Size slider (80%–140%) that applies globally via `MediaQuery.textScaler`.
- [x] **v2.5.0 — Smart Media Date:** Media tiles display a Gregorian date (created → completed → re-opened lifecycle tracking).
- [x] **v2.5.0 — Incomplete Day Indicator:** Shamsi calendar grid shows accent-colored underline on days with pending tasks and emerald bar on fully completed days.
- [x] **v2.6.0 — Canceled Task Progress Tracking Exclusion:** When a task is canceled, it no longer counts in the overall tasks of the day (`dailyTotal` and `taskCompletionMap` exclude canceled tasks, displaying e.g. `0/0 Done` instead of `0/1 Done`).
- [x] **v2.6.0 — Media Status Ordering & Type Dividers:** Entertainment tab partitions items into Uncompleted first, On-Hold second, and Finished at the bottom with horizontal dividers. Any sorter groups media by `MediaType` with horizontal dividing lines preventing different types from appearing directly adjacent.
- [x] **v2.6.0 — Movie Info Fetching Fix:** Enabled `country=US` routing on iTunes Movie Search, added Cinemeta search `releaseInfo` extraction and `/meta/movie/{id}.json` runtime/year deep fetch fallback, and Wikipedia summary fallback.
- [x] **v2.6.0 — Fast-Scroll Rail for Entertainment:** Fixed vertical index rail on right edge with quick-jump targets for Active, On-Hold, and Finished sections, plus proportional drag scrubbing with popout preview bubble.
- [x] **v2.6.0 — Fast-Scroll Rail for Tasks:** Fixed vertical index rail on right edge with quick-jump targets for Today's Focus and Orbit & Backlog (with automatic expansion on jump), plus drag scrubbing to glide between tasks.

---

## 5. Architectural Changelog (Completed Versions)

| Version | Key Enhancements & Milestones Completed |
| :--- | :--- |
| **v1.0.0 – v2.0.0** | Core Day-Planner & Shamsi Agenda; Split task streams; Entertainment ledger (Books, TV, Movies, Games); Local storage persistence; Theme system; Media deletion with cascade handling. |
| **v2.1.0** | Shamsi calendar integration (`persian_datetime_picker`, `persian_number_utility`); Multi-platform app icon generation (Android mipmaps, Web icons, Windows ico); Auto-fetch cover CORS proxies & User-Agent headers; Horizontal swipe page transitions. |
| **v2.2.0** | 4:3 poster aspect ratio enforcement; Progress update numerical validation (`cur <= tot`); Backlog "Assign to Day" context binding; Centered month navigation controls (`« Month`, `Month »`); Comprehensive holiday catalog. |
| **v2.3.0** | Vazirmatn font removal blueprint; Sentence case formatting engine; Persian RTL detection service; Cover art persistent disk cache architecture; Mini-task layout specifications. |
| **v2.4.0** | Theme harmonization (Persian/Nordic merge, Deep Amethyst pitch-black overhaul); Postpone button evolution & multiplier badge; Top bar date & button centering; Sinking Done tasks; Collapsible task streams; Themed progress bars; Space-filling label button wrap; Long-press label deletion; "Fantasy" preset; "Recently Added" sorting; Console/Nintendo game cover pipeline. |
| **v2.4.1** | Clickable section headers (Today's Focus & Orbit/Backlog text + arrow toggles); SafeCoverImage stateful candidate pipeline eliminating 404 infinite loading circle with Steam header & CORS fallback; 4-season theme ordering (Spring Emerald Cyan -> Summer Solar Tangerine -> Autumn Sunset Amber -> Winter Arctic Frost) with distinct Summer citrus-gold and Autumn maple-russet palettes; Multi-platform cover art engine querying LaunchBox, Wikipedia, Libretro (PS2/PS3/PS4/GBA/Switch/GameCube), Steam, and RAWG with Roman numeral/region normalization. |
| **v2.4.2** | Completed (100%) Media Sinking to the bottom of all related lists; Scheduling lock for completed media in MediaCard, main screen, and MediaGoalSyncService; Emerald green border (`0x8010B981`) and background tint; Non-interactive "Completed" action pill replacing Schedule buttons; "Done" overlay badge on cover art; Celebratory emerald progress bar gradient. |
| **v2.5.0** | Hide Hold button on completed media; Reverse Shamsi top-bar date to Day MonthName Year format (`۲۱ آبان ۱۴۰۵`); Remove quotation marks from media descriptions; Add description field in Add Media dialog; Fetch Info button for auto-populating release year/episodes/runtime; Fix default events re-appearing after deletion (deleted-event-ID exclusion set); Persist media sort preference; Remove redundant `+N on check` label from task bottom row; Global font size scaling in Appearance (80%–140%); Smart created/completed date tracking on media tiles (`displayDate`); Visual incomplete-day indicator in Shamsi calendar grid (accent underline bar). |
| **v2.6.0** | Exclude canceled tasks from daily total progress (0/1 -> 0/0 Done); Entertainment uncompleted/on-hold/finished partitioned ordering with horizontal dividers; Type grouping and horizontal dividers between media types on all sorters; Robust movie info & cover fetching via iTunes US routing, Cinemeta search `releaseInfo` + `/meta/movie/{id}.json` detail extraction, and Wikipedia summary fallback; Fixed-rail fast scroller with quick jump and scrubbing for Entertainment (Active, Hold, Done) and Tasks (Focus, Orbit & Backlog). |
