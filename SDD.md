# Software Design Document (SDD)
## Project: NSH Pulse (Lightweight Personal Assistant & Daily Pulse)
**Document Version:** 2.3.0  
**Target Platform:** Android (API 26+, optimized for Samsung Galaxy A12 & modern devices), Flutter Web (Chrome), Windows Desktop  
**Repository:** Local git repository initialized (`main`)  
**Status:** Approved Architecture & Specification (Includes Version 2.3.0 Future Improvement Backlog)

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
| **Video Games** | **Steam Store Search API** | **None (100% Free)** | `https://store.steampowered.com/api/storesearch/?term={title}&l=english&cc=US` (600x900 library posters) | **CheapShark API** / **LaunchBox** |

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

| File Path | Component | Changes Required (Version 2.3.0 Specification) |
| :--- | :--- | :--- |
| `pubspec.yaml` | Manifest | 1) Remove `Vazirmatn` font family declaration.<br>2) Add `cached_network_image: ^3.4.1` for persistent cover disk caching. |
| `assets/fonts/` | Asset Directory | Remove unused `Vazirmatn-Regular.ttf` and `Vazirmatn-Bold.ttf` binaries. |
| `lib/services/title_case_service.dart` | Text Formatting | **Refactor to Sentence Case:** Replace `TitleCaseTextInputFormatter` with `SentenceCaseTextInputFormatter` and `toSentenceCase()`. |
| `lib/services/rtl_detection_service.dart` | Typography / Bidi | **New Service:** Detect Persian/Arabic script to provide dynamic `TextDirection` for task items and text input boxes. |
| `lib/services/cover_cache_service.dart` | Media Caching | **New Service / Component:** Manage local persistent disk caching for fetched media covers so images are never re-downloaded. |
| `lib/theme/app_theme.dart` | Theme & Palettes | 1) Remove `AppFontStyle.vazirmatn` and clean typography fallbacks.<br>2) Rename `Isfahan Cyan` -> `Persian Turquoise`.<br>3) Revitalize 5 bland themes: `Emerald Cyan`, `Nordic Slate`, `Arctic Frost`, `Sunset Amber`, `Cyber Violet`.<br>4) Distinguish and establish unique identities for the 4 purple themes (`Deep Amethyst`, `Deep Lavender`, `Purple & Gold`, `Purple & Orange`). |
| `lib/widgets/shamsi_agenda_banner.dart` | Agenda & Calendar | 1) Restore `+ Event` action button for adding custom events/reminders.<br>2) Dynamic calendar dot colors: Orange for default holidays, pink for birthdays, blue for custom dates. |
| `lib/widgets/task_card.dart` | Task Card UI | 1) Compact mini-tasks: collapse empty space and padding when task has no description notes.<br>2) Holding Tomorrow button opens Shamsi date picker sub-menu (no text box).<br>3) 3-second hold on the card opens edit modal (with dynamic layout support when adding notes).<br>4) RTL text direction support for Persian titles and descriptions. |
| `lib/widgets/media_card.dart` | Media Card UI | 1) Desaturate "Enter Notes" placeholder text color to subtle muted tone.<br>2) Integrate persistent disk image cache renderer (`SafeCoverImage` / `CachedNetworkImage`).<br>3) Add 3-second hold gesture detector on List and Grid cards to open centralized media edit modal. |
| `lib/widgets/safe_cover_image.dart` | Image Renderer | Integrate disk caching layer (`CachedNetworkImage` with CORS fallback) to eliminate repetitive network downloads. |
| `lib/main.dart` | Core Application | 1) Auto-scroll on drag reorder near viewport top/bottom edges.<br>2) Restore Add Event modal dialog flow.<br>3) Replace title case with sentence case across all text input fields.<br>4) Dynamic RTL input detection on `TextField` when first typed character is Persian.<br>5) Unify custom tags across Add Media & Edit Labels into a modal list picker instead of chip clusters.<br>6) Centralized media edit dialog (`_showEditMediaDialog`) triggered on 3-second hold of media cards. |

---

## 5. Verification & Testing Strategy

### 5.1 Device & Display Verification
- **Target Device:** Samsung Galaxy A12 (Android 11/12, One UI Core, screen size: 720 x 1600 px @ ~270 ppi, logical width: 360dp–384dp).
- **Verification Checklist (Version 2.3.0):**
  - [ ] **Font Elimination:** App builds cleanly without `Vazirmatn`; Persian text falls back smoothly to Android's native system Noto Sans Arabic without missing glyphs.
  - [ ] **Sentence Case:** Typing in Task and Media dialogs capitalizes only the first letter of each sentence; subsequent words remain lowercase unless explicitly typed in uppercase.
  - [ ] **Custom Event Creation:** Tapping `+ Event` opens modal, creates custom birthday or milestone event, and displays it in the agenda banner.
  - [ ] **Calendar Dot Colors:** Holiday-only dates display an orange dot (`#F59E0B`). Dates with birthdays display a pink dot (`#EC4899`). Dates with custom events display a blue dot (`#60A5FA`).
  - [ ] **Tomorrow Sub-Menu:** Tapping "Tomorrow" postpones to +1 day. Holding "Tomorrow" opens Shamsi date picker sub-menu directly without any text box dialog.
  - [ ] **Compact Mini-Tasks:** Tasks without description render with tight padding, collapsed spacing, and no empty gap beneath the title.
  - [ ] **Drag Auto-Scroll:** Dragging a task to within 80dp of the top or bottom viewport edge smoothly auto-scrolls the task list.
  - [ ] **Color Differentiation:**
    - `Isfahan Cyan` is renamed `Persian Turquoise`.
    - `Emerald Cyan`, `Nordic Slate`, `Arctic Frost`, `Sunset Amber`, and `Cyber Violet` have deep, vibrant, high-contrast aesthetics.
    - The 4 purple themes (`Deep Amethyst`, `Deep Lavender`, `Purple & Gold`, `Purple & Orange`) possess clearly distinct canvas tones and accent colors.
  - [ ] **Persian RTL Support:** Persian task titles and notes align to the right with RTL text direction. Add Task input box switches dynamically to RTL when first character is Persian.
  - [ ] **3-Second Card Hold:** Holding task card for 3 seconds opens edit dialog. Adding notes to an originally blank mini-task expands the card gracefully.
  - [ ] **Cover Art Cache:** Once a cover art image is fetched, closing and reopening the app or navigating between pages loads the cover instantaneously from local disk cache with 0 network calls.
  - [ ] **Notes Placeholder Tone:** "Enter Notes" / "+ Add personal description/notes..." renders with subtle, desaturated styling.
  - [ ] **Unified Tag Picker:** Both "Add Media" and "Edit Labels" open a modal list of labels (presets + user custom tags) with multi-select and new tag creation, eliminating cluttered button groups.
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
13. **Milestone 13 (Future Backlog - General):** Remove Vazir font entirely; implement Sentence Case text formatting (`SentenceCaseTextInputFormatter`).
14. **Milestone 14 (Future Backlog - Daily Pulse UX):** Restore `+ Event` custom reminder system; implement dynamic multi-colored calendar dots (Orange/Pink/Blue).
15. **Milestone 15 (Future Backlog - Daily Pulse Tasks):** Tomorrow button Shamsi date postponement sub-menu; compact mini-tasks layout; 3-second card hold edit workflow; drag auto-scrolling near edges.
16. **Milestone 16 (Future Backlog - Styling & RTL):** Palette overhaul (rename Isfahan Cyan, revitalize 5 bland palettes, differentiate 4 purple themes); dynamic Persian RTL detection for task cards and input fields.
17. **Milestone 17 (Future Backlog - Entertainment):** Persistent cover art disk cache; desaturated notes placeholder text; unified modal tag list picker for Add Media and Edit Labels; 3-second media tile hold to edit in list and grid views.

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

## 8. Planned Architecture & Feature Enhancements (Version 2.3.0 Specification)

This section contains the comprehensive architectural blueprints, data models, interaction designs, and implementation specifications for the next iteration of NSH Pulse.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 NSH PULSE VERSION 2.3.0                                │
├─────────────────────────┬──────────────────────────────┬───────────────────────────────┤
│         GENERAL         │         DAILY PULSE          │         ENTERTAINMENT         │
├─────────────────────────┼──────────────────────────────┼───────────────────────────────┤
│ • Remove Vazirmatn Font │ • Restore + Event System     │ • Cover Art Disk Caching      │
│ • Universal Sentence    │ • Multi-Color Calendar Dots  │ • Desaturated Note Hint       │
│   Case Formatting       │ • Tomorrow Sub-Menu Picker   │ • Unified Modal Tag Selector  │
│                         │ • Compact Mini-Tasks         │   (Replacing Button Clusters) │
│                         │ • Drag Auto-Scroll at Edges  │ • 3-Second Tile Hold to Edit  │
│                         │ • 11-Theme Color Rework      │                               │
│                         │ • Persian RTL Auto-Detection │                               │
│                         │ • 3-Second Card Hold to Edit │                               │
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

#### 8.2.3 Tomorrow Button Sub-Menu Shamsi Date Postponement
- **Problem Statement:** Holding the "Tomorrow" button currently shows a tooltip or text box dialog. The user requires a direct date-selection sub-menu for rescheduling to any future Shamsi date without entering any text.
- **Architectural Solution:**
  1. **Gesture Differentiation on `Tomorrow` (`lib/widgets/task_card.dart`):**
     - **Quick Tap:** Immediately postpones the task to tomorrow (`currentDate + 1 day`).
     - **Long Press (Hold):** Directly triggers a clean Shamsi date picker sub-menu modal.
  2. **Date Picker Sub-Menu Workflow:**
     ```
     [User Holds "Tomorrow" Button]
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
  3. **Elimination of Text Boxes:** The long-press action strictly avoids any text entry field. Rescheduling operates purely on date coordinates.

#### 8.2.4 Compact Mini-Tasks (Description-less Space Optimization)
- **Problem Statement:** When tasks do not have notes/descriptions (e.g. quick checklist items like *"Call bank"* or *"Water plants"*), `TaskCard` renders blank vertical space, dividers, and padding suited for multi-line notes, causing excessive scrolling.
- **Architectural Solution:**
  1. **Conditional Mini-Task Layout (`TaskCard`):**
     - When `task.notes.trim().isEmpty`:
       - Vertical card padding reduced from `12dp` to `8dp`.
       - Eliminate bottom notes container completely.
       - Reduce divider spacing: change `SizedBox(height: 8)` to `SizedBox(height: 4)`.
       - Compact action button row padding.
  2. **Visual Hierarchy:**
     ```
     Standard Task (With Notes):
     ┌────────────────────────────────────────────────────┐
     │ ≡  [Task Title]                                ✕  │
     │    Multi-line personal description and notes here...│
     │    ───────────────────────────────────────────     │
     │    [Done] [Tomorrow] [Cancel]           ⚡ Schedule│
     └────────────────────────────────────────────────────┘

     Compact Mini-Task (No Notes):
     ┌────────────────────────────────────────────────────┐
     │ ≡  [Task Title]                                ✕  │
     │    ───────────────────────────────────────────     │
     │    [Done] [Tomorrow] [Cancel]           ⚡ Schedule│
     └────────────────────────────────────────────────────┘
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

#### 8.2.6 Colors Rework & Purple Themes Differentiation

##### 8.2.6.1 Rename "Isfahan Cyan"
- **New Name:** **`Persian Turquoise`** (or **`Isfahan Azure`**).
- Refined label in `AppTheme.vibes`: reflects authentic Iranian turquoise tilework (*Firuzeh*) rather than generic synthetic cyan.

##### 8.2.6.2 Revitalize 5 Bland & Generic Color Palettes
The 5 bland themes currently suffer from identical washed-out gray text (`#8B949E` / `#6E7681`) and monochromatic surfaces. They are revitalized with rich saturated canvases, luminous borders, and distinctive accents:

| Theme Enum | New Label | Background Canvas (`bgCanvas`) | Surface (`bgSurface`) | Elevated (`bgElevated`) | Accent Primary (`accentPrimary`) | Accent Gradient Colors | Design Aesthetic |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `emeraldCyan` | **Emerald Cyan** | `#051311` (Deep Jade) | `#0B201D` | `#13302C` | `#10B981` (Vibrant Mint) | `[#059669, #10B981, #06B6D4]` | Luminous emerald rainforest with cyan water glow. |
| `minimalNordic` | **Nordic Slate** | `#0E1318` (Glacial Navy) | `#151D24` | `#1E2832` | `#38BDF8` (Ice Sky) | `[#38BDF8, #818CF8, #C084FC]` | High-contrast Scandinavian frozen slate & glacial aurora. |
| `arcticFrost` | **Arctic Frost** | `#070F1E` (Polar Deep) | `#0D192E` | `#152542` | `#7DD3FC` (Neon Frost) | `[#E0F2FE, #7DD3FC, #38BDF8]` | Sub-zero polar ice with crystalline luminescent glow. |
| `sunsetAmber` | **Sunset Amber** | `#180D0B` (Volcanic Twilight)| `#251512` | `#351E1A` | `#F97316` (Blazing Tangerine)| `[#EA580C, #F97316, #FB7185]` | Warm volcanic dusk embers with coral rose highlights. |
| `cyberViolet` | **Cyber Violet** | `#0D071E` (Synthwave Void) | `#170D31` | `#231448` | `#D946EF` (Electric Fuchsia)| `[#A855F7, #D946EF, #06B6D4]` | Outrun / Cyberpunk neon magenta & electric violet. |

##### 8.2.6.3 Differentiate the 4 Purple Themes
Currently, `Deep Amethyst`, `Deep Lavender`, `Purple & Gold`, and `Purple & Orange` share similar dark purple canvases and violet accents. They are re-architected into 4 sharply contrasting identities:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              THE 4 PURPLE THEME IDENTITIES                             │
├───────────────────────┬────────────────────────┬─────────────────────┬─────────────────┤
│     DEEP AMETHYST     │     DEEP LAVENDER      │    PURPLE & GOLD    │ PURPLE & ORANGE │
├───────────────────────┼────────────────────────┼─────────────────────┼─────────────────┤
│ • Pure Royal Amethyst │ • Ethereal Moonlight   │ • Imperial Luxury   │ • Cyber Dusk    │
│ • Deep plum canvas    │ • Indigo-slate canvas  │ • Pure onyx canvas  │ • Midnight plum │
│   (#0E0616)           │   (#0A0B1A)            │   (#08040C)         │   (#12061A)     │
│ • Vivid violet-purple │ • Pastel misty lilac   │ • Radiant 24k gold  │ • Electric neon │
│   primary (#A855F7)   │   primary (#E9D5FF)    │   primary (#F59E0B) │   tangerine     │
│ • Saturated jewel     │ • Soft radiant glow    │ • High-contrast     │   (#FF6B00)     │
│   tone                │   for low-strain night │   regal gold trims  │ • High-voltage  │
│                       │   reading              │                     │   warm contrast │
└───────────────────────┴────────────────────────┴─────────────────────┴─────────────────┘
```

1. **Deep Amethyst (`deepAmethyst`):**
   - `bgCanvas`: `#0E0616` | `bgSurface`: `#180B26` | `bgElevated`: `#25123A`
   - `accentPrimary`: `#A855F7` (Rich Jewel Amethyst)
   - `accentGradient`: `[#7E22CE, #A855F7, #C084FC]`
2. **Deep Lavender (`electricLavender`):**
   - `bgCanvas`: `#0A0B1A` | `bgSurface`: `#12142B` | `bgElevated`: `#1C1E3F`
   - `accentPrimary`: `#E9D5FF` (Moonlight Pastel Lavender)
   - `accentGradient`: `[#818CF8, #C084FC, #E9D5FF]`
3. **Purple & Gold (`imperialGold`):**
   - `bgCanvas`: `#08040C` | `bgSurface`: `#140A1E` | `bgElevated`: `#211030`
   - `accentPrimary`: `#F59E0B` (Gilded Imperial Gold)
   - `accentGradient`: `[#D97706, #F59E0B, #FDE047]` (Deep purple surface accented exclusively by brilliant golden amber)
4. **Purple & Orange (`purpleOrange`):**
   - `bgCanvas`: `#12061A` | `bgSurface`: `#1F0A2C` | `bgElevated`: `#2F1042`
   - `accentPrimary`: `#FF6B00` (Electric Neon Tangerine)
   - `accentGradient`: `[#9333EA, #FF6B00, #FFAA00]` (Electric clash of deep violet and hot neon citrus)

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

#### 8.3.3 Unified Label Selection Architecture (Modal/List Structure replacing Chip Buttons)
- **Problem Statement:** Custom tags created by the user are only visible when editing existing labels, but are completely absent when adding a new media item. Furthermore, displaying all tags as an uncontrolled horizontal cluster of `FilterChip` buttons creates a cluttered, overflowing dialog UI.
- **Architectural Solution:**
  1. **Unified Tag Pool:**
     - Aggregate both standard presets (`MediaLabelService.presetLabels`) and all user-created custom tags across `_mediaItems`:
       ```dart
       List<String> getAvailableTagPool() {
         final customTags = _mediaItems.expand((m) => m.labels).toSet();
         return {...MediaLabelService.presetLabels, ...customTags}.toList()..sort();
       }
       ```
  2. **Structured Label Selector Bottom Sheet / Modal:**
     - Replace the cluster of buttons with a clean **"Select Labels" Modal Picker**:
       ```
       ┌────────────────────────────────────────────────────────┐
       │ 🏷️ Select Labels / Tags                                 │
       ├────────────────────────────────────────────────────────┤
       │ 🔍 Search or add new tag...                     [ + ]  │
       ├────────────────────────────────────────────────────────┤
       │ Selected (2): [Sci-Fi ✕] [Masterpiece ✕]               │
       ├────────────────────────────────────────────────────────┤
       │ Available Labels:                                      │
       │   [✓] Sci-Fi                                           │
       │   [✓] Masterpiece                                      │
       │   [ ] Cyberpunk (Custom)                               │
       │   [ ] Drama                                            │
       │   [ ] Horror                                           │
       │   [ ] Ongoing                                          │
       │   [ ] Post-Apocalyptic (Custom)                        │
       │   [ ] RPG                                              │
       ├────────────────────────────────────────────────────────┤
       │                         [ Done ]                       │
       └────────────────────────────────────────────────────────┘
       ```
  3. **Parity Across Add and Edit Workflows:**
     - The exact same `LabelSelectionModal` component is invoked during **"Add New Media Item"** and **"Edit Media Labels"**, guaranteeing full access to the user's custom tag library in both workflows.

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

---

## 9. Comprehensive Architectural Summary

This version 2.3.0 specification establishes a complete blueprint for future implementation:
- **Clean Cross-Platform Typography:** Complete removal of `Vazirmatn` font asset overhead, standardizing on native system Perso-Arabic rendering.
- **Sentence Case Input:** Consistent capitalization across tasks, notes, and media entries.
- **Reintroduced Custom Events:** Restores `+ Event` creation for personal birthdays and milestones with distinctive pink and blue calendar dot indicators.
- **Refined Task Controls:** Tomorrow button sub-menu date rescheduling, compact mini-tasks, 3-second hold to edit, drag auto-scrolling at screen boundaries, and dynamic Persian RTL auto-detection.
- **Color Identity Overhaul:** Renaming `Isfahan Cyan` to `Persian Turquoise`, revitalizing 5 bland themes, and creating 4 distinct purple aesthetic identities.
- **Entertainment Resilience & Control:** Persistent cover art disk caching, desaturated placeholder text, unified modal label picker, and 3-second tile hold to open centralized media editor.
