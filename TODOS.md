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
- [x] **16** Light mode: `+` FAB icon now always readable — `floatingActionButtonTheme` added to `AppTheme` with `foregroundColor = onPrimary`.

---

## Habits Screen

- [x] **13** Default selected filter is now **"All"**. Filter order: `All · Today · This week · Yearly · Archive`.
- [x] **14** Haptic celebration on habit completion. 3-pulse `HapticFeedback` sequence fires when a habit transitions to complete (both from `HabitCheckWidget` and the home-screen today row). Configurable via **Settings → General → Celebration haptic** toggle (default: on).
- [x] **19** Habit templates: tapping "New Habit" shows a bottom sheet with 16 pre-built templates (name, emoji, colour pre-filled). User must choose progress type (mandatory). "Start from scratch" option preserved.

---

## Mood Screen

- [x] **5** Yearly vertical mood calendar: new "Year" tab (3rd tab) in Mood screen — shows Jan–Dec month grid with colour-coded mood cells and prev/next year nav arrows.

---

## Focus Screen

- [x] **6** Focus auto-save: timer auto-saves on completion. Removed redundant "Save" button from finished state.

---

## Journal / Notes Screen

- [x] **7.1** Dark mode: double border fixed — uses `context.appColors.border` (theme-adaptive) and `filled: false`.
- [x] **7.2** Note toolbar now placed inside body Column, floats above keyboard when open.
- [x] **7.3** Markdown preview: preview toggle button (👁 icon) added to journal entry AppBar. Preview mode renders `# headings`, `**bold**`, `*italic*`, `` `code` ``, `~~strikethrough~~`, `- bullets`, `1. numbered lists`, `> blockquotes`, and `---` dividers using a custom inline parser (no extra package needed).

---

## Expenses Screen

- [x] **8** Timeline tab added (3rd tab after Accounts): shows month-by-month expense/income bar visualization, newest months first, with auto-formatted amounts (e.g. `1.4k`), net value, and colour-coded bars.

---

## Onboarding / First Login

- [x] **9** First-login skeleton fix: `onboarding_screen._finish()` now calls `dataNotifierProvider.load()` before navigating to home, so home screen populates immediately after first Google sign-in.
- [x] **9.1** Empty home CTA: when a user has no habits, a `_FirstHabitCta` card is shown in the home screen body ("🌱 Start your journey" + "Add first habit" button navigating to Habits).

---

## Settings / Splash

- [x] **12** Splash screen logo: gradient removed, now uses solid primary color.

---

## Heatmap Overlay (Press & Hold on habit card)

- [x] **17.1** Heading in overlay was too low — overlay uses `LayoutBuilder` so all 12 months fit on screen without scrolling.
- [x] **17.2** Horizontal swipe inside overlay no longer changes the bottom nav tab.
- [x] **17.3** Overlay heatmap now shows Jan–Dec of the current year.

---

## Journal Entry / Nav Bar

- [x] **18** Journal entry screen: tapping a nav bar item pops any open fullscreen entry before navigating.

---

## App-wide

- [x] **20** Toast messages: all `showSnackBar` calls replaced with `AppToast.show()` helper (1.8 s, floating pill, type-specific icons: info / success / error). `SnackBarThemeData` added to `AppTheme`.
- [x] **21** Bug fixes: duplicate `_FirstHabitCta` class removed; `flutter analyze` clean across all files.

---

## New — May 2026 (Batch 4)

- [x] **22** Focus auto-save works only if Focus screen is open when timer completes — fix so auto-save fires from the background service regardless of screen visibility.
- [x] **23** Journal entry: rounded corners for title field and tags input area.
- [x] **24** Mood yearly heatmap: show actual mood emoji in each day cell instead of a solid colour block.
- [x] **24.1** Home screen: press-and-hold on the Mood weekly row shows the yearly mood heatmap (same behaviour as habit heatmap overlay).
- [x] **25** Home screen Today section: always show mood tracker row even when user has zero habits (first-time user).
- [x] **25.1** Home screen CTA (first habit): "Add first habit" button should open the new-habit form directly (not redirect to Habits screen then require another tap).
- [x] **26** Habits progress types: fully implement Counter, Timer, and Checklist interactions. Remove Stopwatch as a progress type option. Update home-screen Today row to support inline Counter/Timer/Checklist actions.
- [x] **27** Habit heatmap overlay: background must be fully opaque (zero transparency).
- [x] **28** Expense Timeline tab: add a line/bar chart with time-period filter chips (Week / Month / Quarter / Year, default Month) above the existing list.
- [x] **29** Home screen "This Week" section: tapping a weekly status rectangle expands it to a 4-week monthly heatmap; tapping again collapses it. Togglable per habit row.

---

## New — May 2026 (Batch 5)

- [x] **30** Home screen header: greeting shows user name twice (once small, once large) — remove the small-size duplicate; keep only the large bold name.
- [x] **31** Visual celebration effect on habit/activity completion: confetti / particle burst animation (in addition to haptic), triggered each time a Today row action completes.
- [x] **31.1** Celebration feedback is now modular and fully configurable in Settings → General: individual toggles for Vibration, Sound, and Visual (confetti). All three default to enabled.
- [x] **31.2** Fix any broken behaviour in the existing haptic/celebration feedback.
- [x] **32** Notifications & Reminders: fix and complete the per-habit reminder scheduling (set in Add/Edit Habit → Reminder) so notifications fire reliably; add a global "reschedule all" on app resume; validate Android exact-alarm permission.

---

## New — May 2026 (Batch 6)

- [ ] **33** Expense Timeline period-filter chips are not visible in light mode — fix chip theme contrast for both selected and unselected states.
- [ ] **33.1** Same chip visibility issue in New Habit creation screen: progress-type chips and schedule chips invisible in light mode.
- [ ] **33.2** Add more schedule options: Weekdays (Mon–Fri), Weekends (Sat–Sun), Weekly (one day/week with picker), Monthly (day of month with picker), in addition to Daily and Custom.
- [ ] **34** Habits screen (All / Today view): habits not scheduled for today should render visually disabled (dimmed, non-interactive checkbox) rather than fully functional.
- [ ] **35** Counter progress type edge cases: from the Today section on the home screen, add long-press to decrement; show min/max caps clearly; prevent negative values and wrap-around.
- [ ] **36** Notifications still not firing — root cause: `tz.local` is never set to the device's actual timezone; add `flutter_timezone` dependency and call `tz.setLocalLocation(...)` in `NotificationService.init()`.
- [ ] **37** Timer progress type: marking done should use a time-picker/input flow rather than a plain toggle; undoing a completed timer habit must show "Are you sure?" confirmation.
- [ ] **38** Yearly heatmap (habit and mood): all day cells in the grid should show a subtle border/outline even when empty so the calendar grid is always visible; applies in both light and dark mode.
- [ ] **38.1** Yearly heatmap press-and-hold overlay: day-of-week header labels (M,T,W,T,F,S,S) should use white with higher opacity so they are clearly readable.
- [ ] **39** Expense Timeline chart: replace the bar chart with a line graph; add data labels on each point with smart number formatting.
- [ ] **40** Journal new-entry screen (dark mode): title field and tag input field show a double border (inner sharp rectangle + outer rounded one) — fix so only the outer container border is visible.
- [ ] **40.1** Global UI contrast review: ensure all interactive components (buttons, chips, inputs, cards) have adequate contrast in both light and dark mode.
- [ ] **41** Home screen "This Week" expand/collapse: on expand, animate the current-week row sliding down while the 3 previous-week rows slide in from above; aggregate label should update to "This Month"; no static fixed row at top.
- [ ] **41.1** Today section habit names: long names should wrap to a second line instead of being truncated with "…".
- [ ] **42** Focus screen: add mode-selector chips (Pomodoro / Timer / Stopwatch) so the user can switch between countdown and stopwatch mode; wire selection to `FocusSessionService.configure(mode:)`.
- [ ] **42.1** Home screen weekly status: Focus day-cells use a tall bar shape instead of the square block used by Habits/Journal — fix to use the same square block style with fill ratio.

