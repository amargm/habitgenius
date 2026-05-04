# HabitGenius — Implementation Plan

**Version:** 1.0  
**Date:** May 4, 2026  
**Stack:** Flutter (Dart) · Android first

> **Implementation status as of May 4 2026**  
> Sprints 1–8 in progress. Sprints 1–7 fully shipped. Sprint 8 stability/polish shipped; testing and Play Store release prep remain.
> Latest commit: `e591de1` · Repo: https://github.com/amargm/habitgenius

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

### Sprint 1 — Project Foundation ✅
**Goal:** Running app shell with navigation and theming working end-to-end.

- [x] Create Flutter project, configure `pubspec.yaml`
- [x] Define all 10 `AppColors` constants + `AppLimits` constants
- [x] Build `AppTheme` — `ThemeData` with `ColorScheme.fromSeed()`, dark/light variants
- [x] Build `ThemeProvider` (Riverpod) — persists selection to `SharedPreferences`
- [x] Scaffold all 6 main screens as empty placeholders
- [x] Build `BottomNavWidget` with tier-aware tab visibility
- [x] Wire up `GoRouter` or `Navigator` for screen routing
- [x] Build `SplashScreen` (logo + 1.5s delay, routes to auth or home)
- [x] Verify hot reload, theming switch, navigation all work on emulator

**Deliverable:** Navigable shell app with correct colors, dark mode, all screens reachable.

---

### Sprint 2 — Auth, Onboarding & Data Layer ✅
**Goal:** User can sign in or continue as guest; data file is read/written correctly.

- [x] Build `WelcomeScreen` — Google Sign-In button + Continue as Guest button
- [x] Implement `AuthService` — Google OAuth flow via `firebase_auth` + `google_sign_in`
- [x] Implement guest session (stored in `SharedPreferences`, no Firebase call)
- [x] Build guest-upgrade notice dialog (shown when guest taps Sign In)
- [x] Build `FileSetupScreen` — folder picker via `file_picker`, saves path to prefs
- [x] Build 3-slide `OnboardingScreen` (shown once for new Registered accounts)
- [x] Define all model classes with `json_serializable` code gen:
  - `Habit`, `HabitLog`, `Mood`, `FocusSession`, `JournalEntry`, `Account`, `Transaction`, `AppSettings`, `AppData`
- [x] Build `DataService` — `loadData()`, `saveData()`, file path resolution for guest vs registered
- [x] Build `DataProvider` (Riverpod) — holds `AppData` in memory, exposes mutate methods that auto-save
- [ ] Write unit tests for `DataService` read/write round-trip _(deferred to physical-device testing phase)_

**Deliverable:** Full auth flow working; data persists across app restarts.

---

### Sprint 3 — Habits Feature ✅
**Goal:** Complete habits screen matching prototype design, tier limits enforced.

- [x] Build `HabitsScreen` — chip filter (Today/Week/All), progress bar, habit list
- [x] Build `HabitCheckWidget` — checkbox / counter / timer / stopwatch / checklist variants
- [x] Implement `toggleHabit()` — writes `HabitLog`, updates streak calculation
- [x] Build streak logic — calculate from `habitLogs`, handle missed days
- [x] Build weekly completion grid (`_WeeklyHabitCard` with 7-day dot row per habit)
- [ ] Build yearly heatmap grid _(not implemented — deferred)_
- [x] Build `AddHabitScreen` — name, progress type, schedule, reminder time, icon/emoji picker
- [x] Implement habit limit enforcement per tier (1/3/unlimited) → show `UpgradePromptSheet`
- [x] Schedule local notifications for habit reminders via `NotificationService`
- [x] Wire + / FAB → `AddHabitScreen`, back saves to `DataProvider`

**Deliverable:** Fully working Habits tab with real data persistence and streak tracking.

---

### Sprint 4 — Mood & Focus Features ✅
**Goal:** Both screens working with real data, focus timer runs as foreground service.

**Mood (Registered/Pro only):**
- [x] Build `MoodScreen` — mood selector (5 levels), tag grid, monthly calendar, insight card, stats
- [x] Implement `selectMood()` — one entry per day, update existing if re-selected
- [x] Build mood calendar — dynamic from `moods` data, tap to view/edit past entry
- [x] Build mood trend stats — calculate % positive from last 30 days
- [x] Build locked placeholder for Guest on Mood tab

**Focus:**
- [x] Build `FocusScreen` — category chips, timer ring (SVG), controls, toggle group (25/45/60/Custom)
- [x] Implement `FocusSessionService` — countdown timer logic, pause/resume, Pomodoro cycles
- [ ] Run timer as Android foreground service _(not implemented — timer works in foreground, no persistent notification while running)_
- [x] Save completed `FocusSession` to `DataProvider` on session end
- [x] Build recent sessions list on Focus screen
- [x] Custom duration input — locked for Guest (shows upgrade prompt)
- [x] Build focus stats (today / this week / score)

**Deliverable:** Mood logs and focus sessions save and display correctly; timer survives screen lock.

---

### Sprint 5 — Journal & Expenses Features ✅
**Goal:** Both screens fully working with tier limits enforced.

**Journal:**
- [x] Build `JournalScreen` — search bar, entry list (title, preview, tags, date)
- [x] Build new/edit entry sheet — title input, tag selector, body text area _(inline bottom sheet, no separate route)_
- [x] Implement rich text storage via `flutter_quill` (body stored as plain text + quill delta)
- [x] Implement tag entry (free-text tags, up to 10 per entry)
- [x] Enforce limit: 5 (Guest) / 30 active (Registered) / unlimited (Pro) — show `UpgradePromptSheet`
- [x] Registered deletion frees slot immediately
- [x] Journal search by keyword (title, body, tags)
- [ ] Link mood to journal entry if mood logged same day _(deferred)_

**Expenses (Registered/Pro only):**
- [x] Build `ExpensesScreen` — monthly summary card, Transactions/Accounts tabs, transaction list grouped by date
- [x] Build transaction entry sheet — type toggle, amount, category chips, account picker, note, date picker
- [x] Implement daily limit: count transactions where `date == today`, enforce 4 for Registered
- [ ] Midnight counter reset while app is open _(deferred — resets correctly on next app launch)_
- [ ] Build Analytics view — pie chart via `CustomPainter` _(deferred)_
- [x] Build account management — 2 accounts max for Registered, unlimited for Pro
- [x] Build locked placeholder for Guest on Money tab

**Deliverable:** Journal and Expenses fully functional with all tier limits correctly enforced.

---

### Sprint 6 — Settings, Theming & Upgrade Flow ✅
**Goal:** Settings screen complete; Pro upgrade purchase flow working.

- [x] Build `SettingsScreen` — profile card, appearance, data summary, account section
- [x] Color picker grid — 10 colors, grayed-out Pro-only colors with lock icon for Registered
- [x] Tapping a locked color shows snackbar upgrade prompt
- [x] Dark / Light / System toggle — applies immediately via `ThemeProvider`
- [ ] Data file location row — tap to change folder _(Settings shows data counts; folder-change button deferred)_
- [ ] Manual sync button _(deferred — auto-sync on resume via `SyncService`)_
- [ ] Export / Import backup _(deferred)_
- [x] Implement `PurchaseService` — `in_app_purchase`, product `habitgenius_pro_lifetime`, buy + restore
- [x] Pro upgrade card in Settings — feature bullets, gold gradient, Buy + Restore buttons
- [x] On successful purchase: elevate tier to Pro, persist `isPro` to `SharedPreferences`
- [ ] Notification settings toggles _(deferred)_
- [ ] Currency picker _(deferred)_
- [x] Sign out — clears auth state, returns to Welcome screen

**Deliverable:** Complete settings, theme switching, and working in-app purchase flow.

---

### Sprint 7 — Home Screen, Animations & Polish ✅
**Goal:** Home screen is fully dynamic; all animations match prototype.

- [x] Build dynamic `HomeScreen` — all stats computed from live `DataProvider` data
- [x] Dynamic greeting (Good Morning / Afternoon / Evening based on time)
- [x] Quick Actions grid — shows only actions available to current tier
- [x] Insight card logic — rule engine (all done, streak, focus, mood, fallback)
- [x] Implement screen transition animations (slide-from-right + push-left for detail routes via `CustomTransitionPage`)
- [x] Implement `fadeInUp` staggered animations on Home stats cards (5 slots, 900ms, `Interval` curves)
- [x] Add `HapticFeedback` on habit check, mood selection, timer controls, quick actions
- [ ] Add animated habit check (scale + color transition) _(basic toggle only; scale animation deferred)_
- [x] Implement `SyncService` — on app resume checks file `lastModified`, calls `reload()` if changed
- [x] Empty state illustrations for all screens
- [x] Upgrade prompt sheet polish — smooth bottom sheet, feature list with icons
- [x] Loading states — skeleton shimmer loader while `AsyncValue` is loading

**Deliverable:** App feels polished and animated; Home screen reflects real data.

---

### Sprint 8 — Testing, Edge Cases & Release Prep 🔄 In Progress
**Goal:** App is stable, tested, and ready for Play Store submission.

**Testing:** _(physical-device testing by user — pending)_
- [ ] Unit tests: `DataService`, streak logic, daily limit counter, tier limit checks
- [ ] Widget tests: `HabitCheckWidget`, `UpgradePromptSheet`, `MoodSelector`
- [ ] Integration test: full flow — sign in → add habit → log habit → check home stats
- [ ] Test on 3 device sizes: small (5"), standard (6.1"), large (6.7")
- [ ] Test file sync with a real Google Drive folder (write on device A, read on device B)
- [ ] Test purchase flow with Play Store sandbox account

**Edge cases:**
- [ ] File deleted externally while app is open → graceful error + offer to pick new location _(DataService returns empty data; recovery UI not shown yet)_
- [x] Data file corrupted / invalid JSON → `DataService.loadData()` catches parse errors, returns `AppData.empty()`
- [x] No storage permission granted → `PermissionService` with rationale sheet + OS dialog + permanently-denied path
- [ ] Timer running while app backgrounded → foreground service keeps it alive _(not implemented)_
- [ ] Habit reminder fires while phone is in Do Not Disturb → respects system DND setting _(handled by OS)_
- [ ] Midnight rollover while app is open → reset daily expense counter without restart _(deferred)_

**Stability & polish shipped in Sprint 8:**
- [x] `DataNotifier._save` — non-fatal disk write failure; rolls back in-memory state, logs via `debugPrint`
- [x] `FileSetupScreen`, `_JournalEntrySheet`, `_TransactionSheet`, `_AccountSheet` — all save methods wrapped in `try/catch/finally`; `_saving` always reset
- [x] `RefreshIndicator` pull-to-refresh on Habits, Journal, Expenses lists
- [x] `EmptyStateWidget` + `DataErrorWidget` reusable widgets used across all screens
- [x] Slide-from-right `CustomTransitionPage` on all non-tab routes
- [x] Guest tier shows locked `EmptyStateWidget` instead of rendering Expenses UI
- [x] `PermissionService` — `POST_NOTIFICATIONS` + `SCHEDULE_EXACT_ALARM` with in-app rationale sheets
- [x] Manifest: added `INTERNET`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`
- [x] Core library desugaring enabled (`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4`)

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

| Sprint | Focus | Status |
|---|---|---|
| 1 | Foundation — shell, nav, theming | ✅ Shipped |
| 2 | Auth, onboarding, data layer | ✅ Shipped |
| 3 | Habits feature | ✅ Shipped |
| 4 | Mood + Focus features | ✅ Shipped |
| 5 | Journal + Expenses features | ✅ Shipped |
| 6 | Settings + upgrade/purchase flow | ✅ Shipped |
| 7 | Home screen, animations, polish | ✅ Shipped |
| 8 | Testing, edge cases, release prep | 🔄 In Progress — stability shipped; tests + release prep pending |

**Latest commit:** `e591de1` on `main`  
**Remaining:** unit/widget/integration tests · app icon · Play Store listing · signed AAB

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
