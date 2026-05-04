# HabitGenius — Implementation Plan

**Version:** 1.0  
**Date:** May 4, 2026  
**Stack:** Flutter (Dart) · Android first

---

## Development Environment Setup (Before Sprint 1)

| Task | Details |
|---|---|
| Install Flutter SDK | Latest stable channel |
| Install Android Studio | With Android SDK, emulator (Pixel 8 API 35) |
| Configure VS Code | Flutter + Dart extensions |
| Create Flutter project | `flutter create habitgenius --platforms android` |
| Set min SDK | `minSdkVersion 26` (Android 8.0) |
| Set up Git repo | Branching: `main`, `dev`, feature branches per sprint |
| Set up Google Play Console | For in-app purchases testing (needed in Sprint 5) |
| Configure Firebase project | For Google Sign-In only (no database used) |

---

## Project Folder Structure

```
habitgenius/
├── android/
├── lib/
│   ├── main.dart
│   ├── app.dart                        ← MaterialApp, ThemeData wiring
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart         ← 10 theme color definitions
│   │   │   └── app_limits.dart         ← tier limits (max habits, etc.)
│   │   ├── theme/
│   │   │   ├── app_theme.dart          ← ThemeData builder
│   │   │   └── theme_provider.dart     ← Riverpod notifier
│   │   ├── models/
│   │   │   ├── app_data.dart           ← root data model
│   │   │   ├── habit.dart
│   │   │   ├── habit_log.dart
│   │   │   ├── mood.dart
│   │   │   ├── focus_session.dart
│   │   │   ├── journal_entry.dart
│   │   │   ├── account.dart
│   │   │   └── transaction.dart
│   │   ├── services/
│   │   │   ├── data_service.dart       ← JSON read/write
│   │   │   ├── sync_service.dart       ← file watcher, sync logic
│   │   │   ├── auth_service.dart       ← Google Sign-In / guest
│   │   │   ├── purchase_service.dart   ← Google Play Billing
│   │   │   └── notification_service.dart
│   │   └── providers/
│   │       ├── data_provider.dart      ← global app data state
│   │       ├── auth_provider.dart
│   │       └── settings_provider.dart
│   ├── features/
│   │   ├── splash/
│   │   │   └── splash_screen.dart
│   │   ├── auth/
│   │   │   ├── welcome_screen.dart
│   │   │   └── file_setup_screen.dart
│   │   ├── onboarding/
│   │   │   └── onboarding_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── habits/
│   │   │   ├── habits_screen.dart
│   │   │   └── add_habit_screen.dart
│   │   ├── mood/
│   │   │   └── mood_screen.dart
│   │   ├── focus/
│   │   │   ├── focus_screen.dart
│   │   │   └── focus_session_service.dart
│   │   ├── journal/
│   │   │   ├── journal_screen.dart
│   │   │   └── journal_write_screen.dart
│   │   ├── expenses/
│   │   │   ├── expenses_screen.dart
│   │   │   └── add_expense_screen.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   └── shared/
│       └── widgets/
│           ├── habit_check_widget.dart
│           ├── stat_card_widget.dart
│           ├── upgrade_prompt_sheet.dart
│           ├── bottom_nav_widget.dart
│           └── section_header_widget.dart
├── assets/
│   ├── fonts/
│   └── images/
│       └── logo.png
└── pubspec.yaml
```

---

## Package List

```yaml
dependencies:
  # State management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Auth
  google_sign_in: ^6.2.1
  firebase_auth: ^4.19.4
  firebase_core: ^2.30.1

  # File I/O & storage
  path_provider: ^2.1.3
  file_picker: ^8.0.6

  # Preferences
  shared_preferences: ^2.2.3

  # Notifications
  flutter_local_notifications: ^17.2.1
  timezone: ^0.9.4

  # In-app purchase (Pro upgrade)
  in_app_purchase: ^3.2.0

  # JSON serialization
  json_annotation: ^4.9.0

  # UUID generation
  uuid: ^4.4.0

dev_dependencies:
  build_runner: ^2.4.11
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.0
  flutter_lints: ^4.0.0
```

---

## Sprint Plan

Each sprint = 1 week. Estimated total: **8 sprints (8 weeks)**.

---

### Sprint 1 — Project Foundation
**Goal:** Running app shell with navigation and theming working end-to-end.

- [ ] Create Flutter project, configure `pubspec.yaml`
- [ ] Define all 10 `AppColors` constants + `AppLimits` constants
- [ ] Build `AppTheme` — `ThemeData` with `ColorScheme.fromSeed()`, dark/light variants
- [ ] Build `ThemeProvider` (Riverpod) — persists selection to `SharedPreferences`
- [ ] Scaffold all 6 main screens as empty placeholders
- [ ] Build `BottomNavWidget` with tier-aware tab visibility
- [ ] Wire up `GoRouter` or `Navigator` for screen routing
- [ ] Build `SplashScreen` (logo + 1.5s delay, routes to auth or home)
- [ ] Verify hot reload, theming switch, navigation all work on emulator

**Deliverable:** Navigable shell app with correct colors, dark mode, all screens reachable.

---

### Sprint 2 — Auth, Onboarding & Data Layer
**Goal:** User can sign in or continue as guest; data file is read/written correctly.

- [ ] Build `WelcomeScreen` — Google Sign-In button + Continue as Guest button
- [ ] Implement `AuthService` — Google OAuth flow via `firebase_auth` + `google_sign_in`
- [ ] Implement guest session (stored in `SharedPreferences`, no Firebase call)
- [ ] Build guest-upgrade notice dialog (shown when guest taps Sign In)
- [ ] Build `FileSetupScreen` — folder picker via `file_picker`, saves path to prefs
- [ ] Build 3-slide `OnboardingScreen` (shown once for new Registered accounts)
- [ ] Define all model classes with `json_serializable` code gen:
  - `Habit`, `HabitLog`, `Mood`, `FocusSession`, `JournalEntry`, `Account`, `Transaction`, `AppSettings`, `AppData`
- [ ] Build `DataService` — `loadData()`, `saveData()`, file path resolution for guest vs registered
- [ ] Build `DataProvider` (Riverpod) — holds `AppData` in memory, exposes mutate methods that auto-save
- [ ] Write unit tests for `DataService` read/write round-trip

**Deliverable:** Full auth flow working; data persists across app restarts.

---

### Sprint 3 — Habits Feature
**Goal:** Complete habits screen matching prototype design, tier limits enforced.

- [ ] Build `HabitsScreen` — chip filter (Today/Week/Month/All), progress bar, habit list
- [ ] Build `HabitCheckWidget` — checkbox / counter / timer / stopwatch / checklist variants
- [ ] Implement `toggleHabit()` — writes `HabitLog`, updates streak calculation
- [ ] Build streak logic — calculate from `habitLogs`, handle missed days
- [ ] Build weekly bar chart (custom `CustomPainter`)
- [ ] Build yearly heatmap grid (35-cell → expand to 365 cells)
- [ ] Build `AddHabitScreen` — name, progress type, schedule, reminder time, icon/emoji picker
- [ ] Implement habit limit enforcement per tier (1/3/unlimited) → show `UpgradePromptSheet`
- [ ] Schedule local notifications for habit reminders via `NotificationService`
- [ ] Wire + / FAB → `AddHabitScreen`, back saves to `DataProvider`

**Deliverable:** Fully working Habits tab with real data persistence and streak tracking.

---

### Sprint 4 — Mood & Focus Features
**Goal:** Both screens working with real data, focus timer runs as foreground service.

**Mood (Registered/Pro only):**
- [ ] Build `MoodScreen` — mood selector (5 levels), tag grid, monthly calendar, insight card, stats
- [ ] Implement `selectMood()` — one entry per day, update existing if re-selected
- [ ] Build mood calendar — dynamic from `moods` data, tap to view/edit past entry
- [ ] Build mood trend stats — calculate % positive from last 30 days
- [ ] Build locked placeholder for Guest on Mood tab

**Focus:**
- [ ] Build `FocusScreen` — category chips, timer ring (SVG), controls, toggle group (25/45/60/Custom)
- [ ] Implement `FocusSessionService` — countdown timer logic, pause/resume, Pomodoro cycles
- [ ] Run timer as Android foreground service (persistent notification shows time remaining)
- [ ] Save completed `FocusSession` to `DataProvider` on session end
- [ ] Build recent sessions list on Focus screen
- [ ] Custom duration input — locked for Guest (shows upgrade prompt)
- [ ] Build focus stats (today / this week / score)

**Deliverable:** Mood logs and focus sessions save and display correctly; timer survives screen lock.

---

### Sprint 5 — Journal & Expenses Features
**Goal:** Both screens fully working with tier limits enforced.

**Journal:**
- [ ] Build `JournalScreen` — chip filter by tag, entry list (title, preview, tags, date)
- [ ] Build `JournalWriteScreen` — title input, tag selector, rich text area, toolbar
- [ ] Implement rich text via `flutter_quill` or simple markdown approach
- [ ] Implement tag creation (Registered/Pro custom tags)
- [ ] Enforce limit: 5 (Guest) / 30 active (Registered) / unlimited (Pro) — show `UpgradePromptSheet`
- [ ] Registered deletion frees slot immediately (count = `journal.where(active).length`)
- [ ] Journal search by keyword (Registered/Pro only)
- [ ] Link mood to journal entry if mood logged same day

**Expenses (Registered/Pro only):**
- [ ] Build `ExpensesScreen` — balance card, toggle (Transactions/Analytics/Budget), transaction list grouped by day
- [ ] Build `AddExpenseScreen` — type toggle, amount input, category grid, account picker, note
- [ ] Implement daily limit: count transactions where `date == today (local)`, enforce 4 for Registered
- [ ] Daily counter resets at midnight local time (use `timezone` package)
- [ ] Build Analytics view — pie chart via `CustomPainter` (conic gradient), category breakdown list
- [ ] Build account management — 2 accounts max for Registered, unlimited for Pro
- [ ] Build locked placeholder for Guest on Money tab

**Deliverable:** Journal and Expenses fully functional with all tier limits correctly enforced.

---

### Sprint 6 — Settings, Theming & Upgrade Flow
**Goal:** Settings screen complete; Pro upgrade purchase flow working.

- [ ] Build `SettingsScreen` — profile section, appearance, data & storage, notifications, about
- [ ] Color picker grid — 10 colors, grayed-out Pro-only ones for Registered with lock icon
- [ ] Tapping a locked color shows upgrade prompt for Registered; hidden entirely for Guest
- [ ] Dark / Light / System toggle — applies immediately via `ThemeProvider`
- [ ] Data file location row — shows current path, tap to change (opens `file_picker`)
- [ ] Manual sync button — re-reads file from current path
- [ ] Export backup — copies `habitgenius_data.json` to user-chosen location via SAF
- [ ] Import backup — reads JSON from user-chosen file, merges into current data
- [ ] Implement `PurchaseService` using `in_app_purchase` — connect to Google Play product
- [ ] Build `UpgradeScreen` — feature list, one-time price, Purchase button, Restore Purchase button
- [ ] On successful purchase: update `userTier` to `pro` in settings, persist, reload UI
- [ ] Notification settings: per-notification-type toggles, habit reminder time picker
- [ ] Currency picker — list of common currencies, updates symbol throughout app
- [ ] Sign out — clears auth state, returns to Welcome screen (data file stays untouched)

**Deliverable:** Complete settings, theme switching, and working in-app purchase flow.

---

### Sprint 7 — Home Screen, Animations & Polish
**Goal:** Home screen is fully dynamic; all animations match prototype.

- [ ] Build dynamic `HomeScreen` — all stats computed from live `DataProvider` data
- [ ] Dynamic greeting (Good Morning / Afternoon / Evening based on time)
- [ ] Quick Actions grid — shows only actions available to current tier
- [ ] Insight card logic — simple rule engine (e.g., "You focus better after meditation")
- [ ] Implement all screen transition animations (slide-in from right for tabs, slide-up for detail screens)
- [ ] Implement `fadeInUp` staggered animations on Home stats and habit list items
- [ ] Add `HapticFeedback` on habit check, mood selection, timer controls
- [ ] Add animated habit check (scale + color transition)
- [ ] Implement `SyncService` — on app foreground, check file `lastModified`, reload if changed
- [ ] Empty state illustrations for all screens (no habits yet, no journal entries, etc.)
- [ ] Upgrade prompt sheet polish — smooth bottom sheet, feature list with icons
- [ ] Loading states — skeleton loaders while data reads from file on launch

**Deliverable:** App feels polished and animated; Home screen reflects real data.

---

### Sprint 8 — Testing, Edge Cases & Release Prep
**Goal:** App is stable, tested, and ready for Play Store submission.

**Testing:**
- [ ] Unit tests: `DataService`, streak logic, daily limit counter, tier limit checks
- [ ] Widget tests: `HabitCheckWidget`, `UpgradePromptSheet`, `MoodSelector`
- [ ] Integration test: full flow — sign in → add habit → log habit → check home stats
- [ ] Test on 3 device sizes: small (5"), standard (6.1"), large (6.7")
- [ ] Test file sync with a real Google Drive folder (write on device A, read on device B)
- [ ] Test purchase flow with Play Store sandbox account

**Edge cases:**
- [ ] File deleted externally while app is open → graceful error + offer to pick new location
- [ ] Data file corrupted / invalid JSON → show recovery screen, offer to start fresh
- [ ] No storage permission granted → explain why permission needed
- [ ] Timer running while app backgrounded → foreground service keeps it alive
- [ ] Habit reminder fires while phone is in Do Not Disturb → respects system DND setting
- [ ] Midnight rollover while app is open → reset daily expense counter without restart

**Release prep:**
- [ ] App icon (adaptive icon for Android) — all sizes
- [ ] Play Store screenshots (6 screens × 2 aspect ratios)
- [ ] Play Store listing copy — description, feature bullet points
- [ ] Privacy policy page (required for Google Sign-In + Play Store)
- [ ] Set `versionName` + `versionCode` in `build.gradle`
- [ ] Generate signed release APK / AAB
- [ ] Submit to Play Store internal testing track

**Deliverable:** Signed AAB uploaded to Play Store internal test track.

---

## Timeline Summary

| Sprint | Focus | Week |
|---|---|---|
| 1 | Foundation — shell, nav, theming | Week 1 |
| 2 | Auth, onboarding, data layer | Week 2 |
| 3 | Habits feature | Week 3 |
| 4 | Mood + Focus features | Week 4 |
| 5 | Journal + Expenses features | Week 5 |
| 6 | Settings + upgrade/purchase flow | Week 6 |
| 7 | Home screen, animations, polish | Week 7 |
| 8 | Testing, edge cases, release prep | Week 8 |

**Estimated release:** ~8 weeks from sprint 1 start

---

## Key Technical Decisions

| Decision | Choice | Reason |
|---|---|---|
| State management | Riverpod | Compile-safe, scales well, easy async |
| Navigation | `go_router` | Declarative, handles deep links cleanly |
| JSON serialization | `json_serializable` | Code-gen, no reflection, fast |
| Rich text (Journal) | `flutter_quill` | Best Flutter rich-text package |
| Charts | `CustomPainter` | No extra dependency, matches design exactly |
| Timer service | `dart:async` + Foreground Service | Native Android foreground service for reliability |
| File sync | SAF via `file_picker` + `dart:io` | User controls storage, no server needed |
| In-app purchase | `in_app_purchase` (official Flutter package) | Google Play Billing compliant |

---

## Branch Strategy

```
main          ← production releases only
dev           ← integration branch, always buildable
feature/*     ← one branch per sprint feature
fix/*         ← bug fixes
release/*     ← release candidates
```

Merge flow: `feature/*` → `dev` (PR + review) → `main` (tagged release)

---

## Definition of Done (per feature)

A feature is considered done when:
1. Works on emulator AND a physical device
2. Tier limits enforced — tested for all 3 tiers (guest, registered, pro)
3. Data persists after app kill + reopen
4. No errors in debug console
5. Matches prototype visual design (spacing, colors, animations)
6. Empty state handled (no crash when list is empty)
