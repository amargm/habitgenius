# HabitGenius — Open TODOs

> Update status after each item is completed.
> Status: `[ ]` open · `[~]` in progress · `[x]` done

---

## Home Screen

- [x] **1** Focus weekly status visual: number above day label pushes "W" (Wednesday) up; also gray (unmarked) boxes appear above colored (marked) boxes on the horizontal row — fixed by rendering bar first, label below.
- [x] **2** Mood weekly status visual: unmarked entries show dashes — fixed to use gray boxes (same as other rows).
- [x] **3** Habits weekly status calculation — now filters habits by `createdAt` so days before a habit existed are not counted as missed.
- [x] **4** "X/N done" counter in Today section: mood entry is now counted as +1 activity (total = habits + 1; done increments when today's mood is logged).
- [x] **15** Home username: "HabitGenius" title replaced with the signed-in user's first name.
- [x] **10** Notification bell icon removed from home header.
- [x] **11** Settings avatar: gradient removed, now uses solid primary color.
- [x] **16** Light mode: `+` FAB icon now always readable — `floatingActionButtonTheme` added to `AppTheme` with `foregroundColor = onPrimary` (white for dark primaries, dark text for light primaries).

---

## Habits Screen

- [x] **13** Default selected filter is now **"All"**. Filter order: `All · Today · This week · Yearly · Archive`.
- [ ] **14** Haptic + sound feedback (celebration) on completion of each today habit. Sound configurable in Settings (default: enabled).

---

## Mood Screen

- [x] **5** Yearly vertical mood calendar: new "Year" tab (3rd tab) in Mood screen — shows Jan–Dec month grid with colour-coded mood cells and prev/next year nav arrows.

---

## Focus Screen

- [x] **6** Focus auto-save: timer auto-saves on completion (existing `_onSvcChange` listener). Removed the redundant "Save" button from the finished state; user just taps "New Session" to reset.

---

## Journal / Notes Screen

- [x] **7.1** Dark mode: double border (square outer Container + round inner focus ring) — fixed by using `context.appColors.border` (theme-adaptive) and `filled: false` on the inner TextField.
- [x] **7.2** Note toolbar now placed inside the body Column (not `bottomNavigationBar`) so it floats above the keyboard when open.
- [ ] **7.3** Markdown rendering — toolbar inserts raw syntax (`**bold**`, etc.) but text is not rendered as formatted. `flutter_quill` is in pubspec but journal still uses plain TextField. Needs migration to QuillEditor or a preview-mode toggle.

---

## Expenses Screen

- [ ] **8** Add more visualizations to the expanded expense view: month-wise breakdown, and/or a dedicated "Time Visualization" tab after the Accounts tab.

---

## Onboarding / First Login

- [ ] **9** After first Google sign-in, home screen shows skeleton UI; habits cannot be added. App must be restarted for full UI to load — fix data initialization so home screen populates without restart.
- [ ] **9.1** After landing on home screen (no habits yet), give the user a clear call-to-action / direction on what to do next (e.g. "Add your first habit" empty state prompt).

---

## Settings / Splash

- [x] **12** Splash screen logo: gradient removed, now uses solid primary color.

---

## Heatmap Overlay (Press & Hold on habit card)

- [x] **17.1** Heading in overlay was too low — overlay now uses `LayoutBuilder` to compute aspect ratio so all 12 months fit on screen without scrolling.
- [x] **17.2** Horizontal swipe inside overlay no longer changes the bottom nav tab — overlay wrapped in `GestureDetector` that absorbs drag gestures.
- [x] **17.3** Overlay heatmap now shows Jan–Dec of the current year (not a rolling 365-day window).

---

## Journal Entry / Nav Bar

- [x] **18** Journal entry screen: tapping a nav bar item now pops any open fullscreen entry before navigating — `main_shell.dart` calls `Navigator.popUntil(isFirst)` before `context.go()`.

---

## New (May 2026)

- [x] **19** Habit templates: tapping "New Habit" now shows a template picker sheet with 16 pre-built habits (name, emoji, colour pre-filled). User must choose progress type (mandatory) and optionally set a reminder. "Start from scratch" option preserved.
- [x] **20** Toast messages: replaced all `showSnackBar` calls app-wide with a styled `AppToast.show()` helper. 1.8 s duration, floating pill, dark background matching card surface, type-specific icons (info / success / error). SnackBar theme added to `AppTheme.build()`.
- [x] **21** Bug review: fixed duplicate `_FirstHabitCta` class in `home_screen.dart` (compile error). Confirmed no other issues via `flutter analyze`. Verified recent batch changes (Timeline tab, first-login fix, celebration haptic) are all clean.

---

## Done

<!-- Move completed items here -->
